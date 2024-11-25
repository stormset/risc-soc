# used to adjust the number of cells to be swapped 
variable DECREMENT_FORMULA_MANTISSA 0.9
variable INCREMENT_FORMULA_MANTISSA 1.1

# used to adjust the value of the number of cells swapped in each iteration (exponential behaviour)
proc decay_formula {old_value mantissa exponent} {
    # old_value * mantissa^((1 + exponent)/2)
    return [expr {int(ceil($old_value * ($mantissa**(floor((1 + $exponent)/2)))))}]
}

# Swaps the cells given in the cell_name_list to the VT type given in vt_type.
proc swap_cells {cell_name_list vt_type {set_fail_count 0}} {
    foreach cell_name $cell_name_list {
        set cell [get_cells $cell_name]
        set ref_name [get_attribute $cell ref_name]
        set lib_cell_name [get_attribute $cell lib_cell.full_name]
        set original_vt [get_attribute $cell lib_cell.threshold_voltage_group]

        # extract library name from lib_cell name (e.g. from CORE65LPHVT => CORE65LP)
        regexp {^([^/]+).VT} $lib_cell_name match library_name
        
        # get name of the new Vth group
        set original_vt_char [string index $original_vt 0]
        set original_ref "_L$original_vt_char"
        set target_vt_char [string index $vt_type 0]
        set new_ref "_L$target_vt_char"

        if {$original_vt != $vt_type} {
            # swap cell
            set library_name "${library_name}${vt_type}"
            regsub $original_ref $ref_name $new_ref new_ref_name
            size_cell $cell "${library_name}/${new_ref_name}" > /dev/null

            # in case set_fail_count is true we increment the fail_count user defined attribute of the cell
            # this is used to keep track of the number of times swapping a cell was tried
            if {$set_fail_count} {
              set attr [get_attribute -quiet $cell fail_count]
              set_user_attribute -quiet $cell fail_count [expr {$attr + 1}]
            }
        }
    }
}

# Performs the back swapping of cells to LVT given in the cell_name_list up until the slack becomes >= 0.
# we do this in an incremental way, thus we start swapping back 1 cell at first, and as we proceed
# we increase the number of cells swapped to speed up
proc swap_cells_back {cell_name_list} {
    # start swapping back from the other end, since the list is sorted by cost function (best to keep is at the beginning)
    set cell_name_list [lreverse $cell_name_list]
    set init_count [llength $cell_name_list]
    set swap_back_count 1
    set swapped_count 0
    
    set it_ct 0
    while {1} {
        set len [llength $cell_name_list]
        if {$swap_back_count > $len} {
            set swap_back_count $len
        }

        # swap back swap_back_count cells to LVT and increase their fail_count attribute by 1
        set cell_names [lrange $cell_name_list 0 [expr {$swap_back_count - 1}]]
        swap_cells $cell_names {LVT} 1
        set swapped_count [expr {$swapped_count + $swap_back_count}]

        # remove swapped back cells from list
        set cell_name_list [lrange $cell_name_list $swap_back_count end]

        update_timing -full
        set slack [get_attribute [get_timing_paths] slack]
        if {$slack >= 0} {
            # slack >= 0 met => DONE
            break
        } else {
            # otherwise => increase the number of cells swapped
            set swap_back_count [decay_formula $swap_back_count $::INCREMENT_FORMULA_MANTISSA $it_ct]
            set it_ct [expr {$it_ct + 1}]
        }

        if {[llength $cell_name_list] == 0} {
            break
        }
    }

    # return the number of cells we managed to keep
    set diff [expr {$init_count - $swapped_count}]
    return $diff
}

# Returns the names of LVT cells in a list ordered by the cost function (most promising is first).
#     min_fail_count: if > 0, then it will return cells that have fail_count attribute >= min_fail_count
proc get_sorted_cell_names_to_swap {{min_fail_count 0}} {
    # get output pins of LVT cells
    if {$min_fail_count == 0} {
        set lvt_out_pin_collection [get_pins -quiet -filter "@cell.lib_cell.threshold_voltage_group == LVT && direction == out"]
    } else {
        set lvt_out_pin_collection [get_pins -quiet -filter "@cell.lib_cell.threshold_voltage_group == LVT && direction == out && @cell.fail_count >= $min_fail_count"]
    }

    if {[sizeof_collection $lvt_out_pin_collection] == 0} {
        return {}
    }

    # prepare cell list for sorting (get attributes of cells used as cost function)
    set cells_with_costs {}
    foreach_in_collection lvt_out_pin $lvt_out_pin_collection {
        set cell [get_attribute $lvt_out_pin cell]

        set slack [get_attribute $lvt_out_pin max_slack]
        set fail_count [get_attribute $cell fail_count]
        set area [get_attribute $cell area]

        set cell_props {}
        lappend cell_props $cell
        lappend cell_props $slack
        lappend cell_props $fail_count
        lappend cell_props $area
        lappend cells_with_costs $cell_props
    }

    # sort by cost function (fail_count first (increasing), then by slack (decreasing), then by cell size)
    set cells_with_costs_sorted [lsort -index 2 [lsort -real -decreasing -index 1 [lsort -real -decreasing -index 3 $cells_with_costs]]]

    # return names of cells only
    return [lmap e $cells_with_costs_sorted {get_attribute [lindex $e 0] full_name}]
}

# Performs a coarse grained swapping of cells to type given in new_cell_type.
# it will start by trying to swap large number of cells, then in case the slack is negative,
# it will revert the swap and decrease the value of the number of cells to be swapped
# when the count of cells to be swapped reaches 0 we finish
proc coarse_grained_opt {num_epoch new_cell_type} {
    # number of cells to swap at once
    set N [llength [get_sorted_cell_names_to_swap]]
    # current iteration
    set epoch 0
    # counts how many times in a row we hit negative slack (this will result in more rapid decrement of N)
    set slack_pos_count 0
    # only get the new cell list to swap in case previous swap was successful (saves time)
    set need_update 1

    set to_swap {}
    while {1} {
        puts "coarse grained epoch $epoch (N = $N)"

        if {$need_update} {
            set to_swap [get_sorted_cell_names_to_swap]
            if {[llength $to_swap] == 0} {
            break
            }
        }

        set to_swap [lrange $to_swap 0 [expr $N-1]]
        swap_cells $to_swap $new_cell_type

        update_timing -full
        set slack [get_attribute [get_timing_paths] slack]
        if {$slack < 0} {
            set slack_pos_count [expr {$slack_pos_count + 1}]

            swap_cells $to_swap {LVT}
            set need_update 0
            update_timing -full

            set N [decay_formula $N $::DECREMENT_FORMULA_MANTISSA $slack_pos_count]
        } else {
            set slack_pos_count 0
            set need_update 1
        }

        if {$epoch >= $num_epoch || $N == 0} {
            break
        }

        set epoch [expr {$epoch + 1}]
    }
}

# Performs a fine grained swapping of cells to type given in new_cell_type.
# it will start by trying to swap a single cell only, then in case the resulting slack is still positive,
# we increase the value of the number of cells to be swapped, otherwise we decrease it
proc fine_grained_opt {num_epoch new_cell_type} {
    # number of cells to swap at once
    set N 1
    # current iteration
    set epoch 0
    # counts how many times in a row we hit negative slack (this will result in more rapid decrement of N)
    set slack_neg_count 0
    # counts how many times in a row we hit positive slack (this will result in more rapid increment of N)
    set slack_pos_count 0
    # we retry to swap cells we already swapped (based on fail_count cell attribute) in case retry_swap_count > 0
    set retry_swap_count 0

    set to_swap {}
    while {1} {
        puts "fine grained epoch $epoch (N = $N)"

        set doing_retry_swap [expr {$retry_swap_count > 0}]
        if {$doing_retry_swap} {
            # get cells with failed count >= 1
            set to_swap [get_sorted_cell_names_to_swap 1]
            if {[llength $to_swap] == 0} {
                set to_swap [get_sorted_cell_names_to_swap]
            }
        } else {
            set to_swap [get_sorted_cell_names_to_swap]
        }
        
        if {[llength $to_swap] == 0} {
            break
        }

        set to_swap [lrange $to_swap 0 [expr $N-1]]
        swap_cells $to_swap $new_cell_type

        update_timing -full
        set slack [get_attribute [get_timing_paths] slack]
        if {$slack < 0} {
            set slack_neg_count [expr {$slack_neg_count + 1}]
            set slack_pos_count [expr {max($slack_pos_count - 1, 0)}]

            set ct [swap_cells_back $to_swap]
      
            if {$ct > 0} {
                # set N to the number of cells we were able to swap
                set N $ct

                if {$doing_retry_swap} {
                    # in case we are retrying and we succeeded (ct > 0, thus we managed to swap some retried cells)
                    # we increase retry_swap_count, thus we will keep swapping retried cells (reward)
                    set retry_swap_count [expr {$retry_swap_count + 1}]
                }
            } else {
                set N [decay_formula $N $::DECREMENT_FORMULA_MANTISSA $slack_neg_count]
                set N [expr {max($N, 1)}]

                if {$doing_retry_swap} {
                    # in case we are retrying and we fail (ct < 0, thus we didn't managed to swap retried cells)
                    # we decrease retry_swap_count, thus we will stop swapping retried cells (penalty)
                    set retry_swap_count [expr {$retry_swap_count - 1}]
                }
            }

            if {!$doing_retry_swap} {
                # in case we are NOT retrying, but we fail swapping (slack < 0), we increase retry_swap_count,
                # in order to start retrying
                set retry_swap_count [expr {$retry_swap_count + 1}]
            }
        } else {
            set slack_pos_count [expr {$slack_pos_count + 1}]
            set slack_neg_count [expr {max($slack_neg_count - 1, 0)}]

            set N [decay_formula $N $::INCREMENT_FORMULA_MANTISSA $slack_pos_count]
        }

        if {$epoch >= $num_epoch} {
            break
        }

        set epoch [expr {$epoch + 1}]
    }
}

proc multiVth {} {
    # create a new user defined attribute on cells
    # this keeps track of the number of times we tried to swap a given cell but failed
    define_user_attribute -type int -class cell fail_count
    set_user_attribute -quiet [get_cells *] fail_count 0

    # run coarse grained swapping to HVT cells
    coarse_grained_opt 80 {HVT}

    # run fine grained swapping to SVT cells (at this point slack could be very small hence we do fine grained optimization)
    fine_grained_opt 160 {SVT}
}
