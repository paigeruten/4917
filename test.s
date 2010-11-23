#
# This program tests two numbers for equality. If they're the same, it rings
# the bell once. If they're different, it rings it twice.
#

# Store a couple numbers at the end of the memory.
.data first_num, 10
.data second_num, 6

# This label is just for show.
_start:
  mov  $first_num, %r0                 # Move data into registers.
  mov  $second_num, %r1
  sub                                  # Subtract first_num - second_num.
  jnz  theyre_different                # If they're different, go down there.
  bell                                 # Otherwise ring bell once.
  jmp  exit                            # And exit.

theyre_different:
  bell                                 # Ring two bells to say the numbers are
  bell                                 # different.

exit:
  halt                                 # Stop the program.

#
# If one more instruction is added to this program, the code and data sections
# would overlap. That's how little space we have to work with!
#

