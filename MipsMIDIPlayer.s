##################################################################################
#           ______   ____    ____                 ______   ____    ______     
#   /'\_/`\/\__  _\ /\  _`\ /\  _`\       /'\_/`\/\__  _\ /\  _`\ /\__  _\    
#  /\      \/_/\ \/ \ \ \L\ \ \,\L\_\    /\      \/_/\ \/ \ \ \/\ \/_/\ \/    
#  \ \ \__\ \ \ \ \  \ \ ,__/\/_\__ \    \ \ \__\ \ \ \ \  \ \ \ \ \ \ \ \    
#   \ \ \_/\ \ \_\ \__\ \ \/   /\ \L\ \   \ \ \_/\ \ \_\ \__\ \ \_\ \ \_\ \__ 
#    \ \_\\ \_\/\_____\\ \_\   \ `\____\   \ \_\\ \_\/\_____\\ \____/ /\_____\
#     \/_/ \/_/\/_____/ \/_/    \/_____/    \/_/ \/_/\/_____/ \/___/  \/_____/                                                                                                                                                         
#                ____    ___                                     
#               /\  _`\ /\_ \                                    
#               \ \ \L\ \//\ \      __     __  __     __   _ __  
#                \ \ ,__/ \ \ \   /'__`\  /\ \/\ \  /'__`\/\`'__\
#                 \ \ \/   \_\ \_/\ \L\.\_\ \ \_\ \/\  __/\ \ \/ 
#                  \ \_\   /\____\ \__/.\_\\/`____ \ \____\\ \_\ 
#                   \/_/   \/____/\/__/\/_/ `/___/> \/____/ \/_/ 
#                                              /\___/            
#                                              \/__/             
# 
##################################################################################
#	
#	Console Development - Assignment 1
#	Written By Timothy Leonard
#
#	Second Rewrite following USB Failure
# 
##################################################################################
 
# --------------------------------------------------------------------------------
# 	Data Segment
# --------------------------------------------------------------------------------
.data
  	
StackData: 		.space 		16384 							# 16k of memory reserved for stack.

.align 2
NoteData: 		.space 		1048576							# 1MB of memory reserved for note data.

.align 2
NoteDataCompressed:	.space 		1048576							# 1MB of memory reserved for compressed note data.
 
PulsesPerQuater: 	.word		0							# Pulses per quater (timing system).

BeatsPerMinute: 	.word		110							# Beats Per Minutes

MillisecondsPerTick: 	.word		0							# Number of milliseconds per tick.

ChannelProgram:		.space		64							# Array of words, stores the program for each channel (space for 16 channels).
ChannelVolume:		.space		64							# Array of words, stores the volume for each channel (space for 16 channels).
 
TmpBuffer1:		.word		255							# Temporary word buffer.

NoteCount:		.word		0							# Stores number of notes currently loaded.
 
CompressedNoteSize:	.word		0							# Stores the size (in bytes) of the compressed note block.
 
TmpBufferString1:	.space		255

UncompressingNotice:	.asciiz		"Loading and uncompressing data file, please wait...\n"	# These strings are just used to tell the user whats currently going on. 
PrePlayNotice:		.asciiz		"Loading complete, begining playback...\n"
HeaderNotice:		.asciiz		"######################################\n  MIPS MIDI Music Sequencer\n  Written By Timothy Leonard\n######################################\n\n"
SelectionMenu:		.asciiz		"1. Play Sample 1\n2. Play Sample 2\n3. Play Sample 3\n4. Exit\nOr enter file name for specific file.\n\nEnter Option > "
FinishPlayNotice:	.asciiz		"Finished Playing.\n\n"

Sample1FileName:	.asciiz		"Examples/Dark World.mid.asmdat"
Sample2FileName:	.asciiz		"Examples/Lost Woods.mid.asmdat"
Sample3FileName:	.asciiz		"Examples/Kakariko.mid.asmdat"

# --------------------------------------------------------------------------------
# 	Code Segment
# --------------------------------------------------------------------------------
.text

# Initialize stack.
jal InitStack

# Call main function.
la $v0, MainFunction
jal CallFunction

# Exit application
li $v0, 10
syscall

# --------------------------------------------------------------------------------
# 	MainFunction:  Contains the main loop. Ask the player what file they wish 
#		       to load, etc.
# --------------------------------------------------------------------------------
MainFunction:

	# Emit header.
	li $v0, 4
	la $a0, HeaderNotice
	syscall

	MainLoopStart:

		# Ask the user to enter filename or example music.
		li $v0, 4
		la $a0, SelectionMenu
		syscall

		# Read in the choice the user made.
		li $v0, 8
		la $a0, TmpBufferString1
		li $a1, 255
		syscall

		# Work out what option they choose.

			# Load in first character in string
			lb $t0,TmpBufferString1		

			# Jump depending on what it is.
			beq $t0, 49, Sample1Chosen
			beq $t0, 50, Sample2Chosen
			beq $t0, 51, Sample3Chosen
			beq $t0, 52, Sample4Chosen
	 
			# Default block - run if the user enters a custom filename.

				# TODO: Need some error checking here incase file can't be opened.

				# Right, first we need to strip the \n that gets appended to our string for
				# god only knows what reason by mars (probably because it's following the fgets convention).
				li $t1, 0
				la $t2, TmpBufferString1
				RemoveNewLineStart:
					  
					# Jump out of loop if we have gone through entire buffer.
					beq $t1, 255, RemoveNewLineEnd

					# Load in value at buffer.
					lb $t3, 0($t2)
					
					# Don't strip out character if it's not a newline.
					beq $t3, 10, IsNewLine
					beq $t3, 13, IsNewLine
					j NotNewLine
					IsNewLine:
		 
						# Store a null byte in the newlines places.
						li $t4, 0
						sb $t4, 0($t2) 

					NotNewLine:
				
					# Add one to the offset into the buffer.
					addi $t1, $t1, 1				
					addi $t2, $t2, 1

				j RemoveNewLineStart
				RemoveNewLineEnd:

				# Tell user what we are doing.
				li $v0, 4
				la $a0, UncompressingNotice
				syscall

				# Load this song.
				la $v0, LoadSong
				la $a0, TmpBufferString1
				jal CallFunction

				j EndOfSampleSelectBlock

			# Jumped to if the user asks to play the first sample.
			Sample1Chosen:

				# Tell user what we are doing.
				li $v0, 4
				la $a0, UncompressingNotice
				syscall

				# Load this song.
				la $v0, LoadSong
				la $a0, Sample1FileName
				jal CallFunction

				j EndOfSampleSelectBlock

			# Jumped to if the user asks to play the second sample.
			Sample2Chosen:

				# Tell user what we are doing.
				li $v0, 4
				la $a0, UncompressingNotice
				syscall

				# Load this song.
				la $v0, LoadSong
				la $a0, Sample2FileName
				jal CallFunction

				j EndOfSampleSelectBlock

			# Jumped to if the user asks to play the third sample.
			Sample3Chosen:	
	
				# Tell user what we are doing.
				li $v0, 4
				la $a0, UncompressingNotice
				syscall

				# Load this song.
				la $v0, LoadSong
				la $a0, Sample3FileName
				jal CallFunction

				j EndOfSampleSelectBlock

			# Jumped to if the user asks to exit.
			Sample4Chosen:	

				j ReturnFunction

			# This label is used so we can jump past all the code in
			# the previous labels.
			EndOfSampleSelectBlock:

		# Tell user what we are doing.
		li $v0, 4
		la $a0, PrePlayNotice
		syscall

		# Start playing the song.
		la $v0, PlaySong
		jal CallFunction

		# Tell user what we are doing.
		li $v0, 4
		la $a0, FinishPlayNotice
		syscall

	j MainLoopStart

j ReturnFunction

# --------------------------------------------------------------------------------
# 	LoadSong: Loads a binary data file into the player to be used
#		  as a song to play.
#
#		$a0 : Filename of file to load.
# --------------------------------------------------------------------------------
LoadSong:

	# Locals:
	#
	#	$t0 = Stores file descriptor.
	#	$t1 = Number of notes in file.
	#	$t2 = Size of note block in file.
	#	$t3 = Size of each note block.
	#

	# ------------------------------------------------------------------------
	# Open the file (syscall 13)
	# ------------------------------------------------------------------------

		li $v0, 13 
		# $a0 already filled in (filename).
		li $a1, 0 # $a1 flags
		li $a2, 0 # $a2 mode
		syscall

		# Store file descriptor.
		move $t0, $v0

	# ------------------------------------------------------------------------
	# Read in header (read: syscall 14).
	# ------------------------------------------------------------------------
	
		# Read in number of notes (4 byte integer).
		li $v0, 14
		move $a0, $t0
		la $a1, TmpBuffer1
		li $a2, 4
		syscall

		# Store the value.
		lw $t1, TmpBuffer1

		# Store number of notes loaded.
		sw $t1, NoteCount

		# Read in pulses per quater (PPQ)
		li $v0, 14
		move $a0, $t0
		la $a1, PulsesPerQuater
		li $a2, 4
		syscall

		# Read in size of compressed notes.
		li $v0, 14
		move $a0, $t0
		la $a1, CompressedNoteSize
		li $a2, 4
		syscall

		# Work out how many milliseconds per tick;
		# ppq = Pulses per quater (240)
		# bpm = quaters (beats) per minute (120)
		#
		# (bpm * ppq = 28800 ticks per minute)
		# 60000 / ticks per minute = ms per tick 
		li $s1, 60000
		lw $s2, PulsesPerQuater
		lw $s3, BeatsPerMinute

		mul $s4, $s3, $s2
		div $s5, $s1, $s4

		sw $s5, MillisecondsPerTick

		# Set default volume of channels
		# TODO: Use loop, this is ineligant.
		li $s5, 127
		la $s6, ChannelVolume
		sw $s5, 0($s6) 
		sw $s5, 4($s6)
		sw $s5, 8($s6)
		sw $s5, 12($s6)
		sw $s5, 16($s6)
		sw $s5, 20($s6)
		sw $s5, 24($s6)
		sw $s5, 28($s6)
		sw $s5, 32($s6)
		sw $s5, 36($s6)
		sw $s5, 40($s6)
		sw $s5, 44($s6)
		sw $s5, 48($s6)
		sw $s5, 52($s6)
		sw $s5, 56($s6)
		sw $s5, 60($s6)

	# ------------------------------------------------------------------------
	# Read in notes.
	# ------------------------------------------------------------------------

		# Work out total size of notes (each note structure is 28 bytes).
		lw $t2, CompressedNoteSize

		# Read in all the compressed notes.
		li $v0, 14
		move $a0, $t0
		la $a1, NoteDataCompressed
		move $a2, $t2
		syscall

		# Decompress all the notes.
		la $v0, RLEDecompress
		la $a0, NoteDataCompressed
		la $a1, NoteData
		lw $a2, CompressedNoteSize
		jal CallFunction
		
	# ------------------------------------------------------------------------
	# Close file (syscall 16).
	# ------------------------------------------------------------------------

		li $v0, 16
		move $a0, $t0
		syscall

j ReturnFunction

# --------------------------------------------------------------------------------
# 	RLEDecompress: Decompresses the given buffer using the RLE 
#		       compression scheme.
#
#		$a0 : Address of buffer containing compressed data.
#		$a1 : Address of buffer to store decompressed data in.
#		$a2 : Size (in bytes) of compressed data.
# --------------------------------------------------------------------------------
RLEDecompress:

	# Locals:
	#	
	#	$t0 : Index into compressed buffer.
	#	$t1 : Unused
	#	$t2 : Pointer to current compressed byte.
	#	$t3 : Current compressed byte.
	#	$t4 : Number of bytes to uncompress.
	#	$t5 : Pointer of current uncompressed byte.
	#	$t6 : Pattern byte to uncompress.
	#
 
	li $t0, 0
	move $t5, $a1
 
	UncompressLoop:

		# Break out of loop if we are at the end.
		bgt $t0, $a2, UncompressLoopEnd
		
		# Work out address to current compressed byte.
		move $t2, $a0
		add $t2, $t2, $t0

		# Read in current byte.
		lbu $t3, 0($t2)

		# If byte is greater than 127 it's compressed.
		blt $t3, 127, UncompressedByte		

			# Increment index.
			addi $t0, $t0, 1
			
			# Read in pattern byte
			lbu $t6, 1($t2)
		
			# Work out how many bytes to uncompress.
			sub $t4, $t3, 127

			# Write uncompressed bytes into array.
			WriteUncompressByteStart:

				# Break if we have uncompressed all bytes.
				ble $t4, 0, WriteUncompressByteEnd 

				# Write uncompressed bytes into array
				sb $t6, 0($t5)

				# Increment uncompressed byte index.
				addi $t5, $t5, 1

				# Decrement number of bytes to uncompress.
				subi $t4, $t4, 1

			j WriteUncompressByteStart
			WriteUncompressByteEnd:

			j CompressedByteEnd

		# Otherwise not
		UncompressedByte:

			# Write uncompressed bytes into array
			sb $t3, 0($t5)

			# Increment uncompressed byte index.
			addi $t5, $t5, 1

		# End of if block.
		CompressedByteEnd:

		# Increment compressed byte index.
		addi $t0, $t0, 1

	j UncompressLoop
	UncompressLoopEnd:

j ReturnFunction

# --------------------------------------------------------------------------------
# 	PlaySong: Goes through each of the notes that have
#		  been loaded and plays them in order.
# --------------------------------------------------------------------------------
PlaySong:

	# Locals:
	#
	#	$t0  :  Pointer to note structure currently being played.
	#	$t1  :	Note counter.
	#	$t2  :	Total number of notes loaded.
	#
	#	$t3  :  Cumulative Time of current note
	#	$t4  :	Delta Time of current note
	#	$t5  :	Note event type
	#	$t6  :	Note pitch
	#	$t7  :	Note Velocity
	#	$t8  :	Note value
	#	$t9  :  Channel of current note

	#	$s0  : 	Cumulative Time of next note
	#	$s1 : Address of channel program.
	#	$s2 : Temporary
	#	$s3 : Instrument to play on the current notes channel
	#	$s4 : Temporary 2
	#
	#	$s5 : Address of channel volume
	#	$s6 : Channel volume
	#	
	#	$s7 : If true we don't a delay before next note.
	#

	# Make note data pointer point to start of data.
	la $t0, NoteData

	# Load total number of notes.
	lw $t2, NoteCount

	# Loop through notes until we get to the end.
	PlayLoopStart:
	
		# Check if we are at the end of notes yet.
		addi $t1, $t1, 1 # Increment note counter.
		bge $t1, $t2, PlayLoopEnd # FIX: this skips last note, but we can't read last note as $t9 (next cumTime) will end up 
					  #      loading from an out-of-range memory address.

		# Load in all the data from the note.
		lw $t3, 0($t0)
		lw $t4, 4($t0)
		lb $t5, 8($t0)
		lb $t6, 9($t0)
		lb $t7, 10($t0)
		lb $t8, 11($t0)
		lw $t9, 12($t0)
		lw $s0, 16($t0)

		# Multiply duration with PPQ
		lw $s2, MillisecondsPerTick
		mul $t4, $t4, $s2 # Delta Time
		mul $t7, $t7, $s2 # Velocity
		


		# Load address of channel program array.
		la $s1, ChannelProgram

		# Work out address into channel program array.
		# Addr = ChannelProgram + (Channel * 4)
		li $s4, 4
		mul $s2, $t9, $s4
		add $s1, $s2, $s1

		# Load instrument of channel to play.
		lw $s3, 0($s1)


		# Load address of channel volume array.
		la $s5, ChannelVolume

		# Work out address into channel volume array.
		# Addr = ChannelVolume + (Channel * 4)
		li $s4, 4
		mul $s2, $t9, $s4
		add $s5, $s2, $s5

		# Load volume of channel to play.
		lw $s6, 0($s5)



		# If set to true we skip the delay before the next note.
		li $s7, 0

		# Switch block depending on what kind of event this is.
		beq $t5, 0, NoteEventSwitchNoteOn
		beq $t5, 1, NoteEventSwitchProgramChange
		#beq $t5, 2, NoteEventSwitchControlChange
		j NoteEventSwitchEnd

			# Play the current note.
			NoteEventSwitchNoteOn:
				
				# Syscall 38 (Change midi channel)
				li $v0, 38
				move $a0, $t9 # Channel
				move $a1, $s3 # Instrument
				syscall

				# Syscall 37 (MIDI Note Play)
				li $v0, 37
				move $a0, $t6 # Pitch
				#move $a1, $t4 # Duration
				move $a1, $t7 # Velocity of note (>0 duration, 0 for note off)
				move $a2, $t9 # Channel
				move $a3, $s6 # Volume
				syscall

				# Note with vel of 0 = note-off

				j NoteEventSwitchEnd

			# Change the current instrument.
			NoteEventSwitchProgramChange:

				# Store the current instrument for the channel.
				sw $t8, 0($s1)

				# Skip delay
				#li $s7, 1

				j NoteEventSwitchEnd

			# Change control event
			#NoteEventSwitchControlChange:
				
				#bne $t8, 7, NoteEventSwitchEnd
				#sw $t8, 0($s5)

				# Skip delay
				#li $s7, 1
 
				#j NoteEventSwitchEnd

		NoteEventSwitchEnd:

		# Work out the difference between the current note time and the time for 
		# the next note and wait for that long.
		beq $s7, 1, SkipDelay

			li $v0, 32
			sub $a0, $s0, $t3
		
			lw $s4, MillisecondsPerTick
			mul $a0, $a0, $s4

			syscall 
 
		SkipDelay:

		# Increment pointer by size of note structure (16 bytes)
		addi $t0, $t0, 16

	j PlayLoopStart

	PlayLoopEnd:

j ReturnFunction

# --------------------------------------------------------------------------------
# 	InitStack: Initializes the stack so CallFunction and ReturnFunction
#		   can be used.
#	
#		   Our stack is upwards growing. From low to high addresses. 
# --------------------------------------------------------------------------------
InitStack:

	# Set stack pointer to top of stack.
	la $sp, StackData

jr $ra

# --------------------------------------------------------------------------------
# 	CallFunction: Pushs a return address onto the stack as well
#		       as all $s#, $t# and $a# registers.
#
#		$v0  : Function to call.
# --------------------------------------------------------------------------------
CallFunction:

	# Stack bounds checking is not really neccessary in mars
	# as it's impossible to read/write to the text segment anyway.

	# Push return address onto stack.
	sw $ra, 0($sp)

	# Push registers onto stack.
	sw $a0, 4($sp)
	sw $a1, 8($sp)
	sw $a2, 12($sp)
	sw $a3, 16($sp)
	sw $t0, 20($sp)
	sw $t1, 24($sp)
	sw $t2, 28($sp)
	sw $t3, 32($sp)
	sw $t4, 36($sp)
	sw $t5, 40($sp)
	sw $t6, 44($sp)
	sw $t7, 48($sp)
	sw $s0, 52($sp)
	sw $s1, 56($sp)
	sw $s2, 60($sp)
	sw $s3, 64($sp)
	sw $s4, 68($sp)
	sw $s5, 72($sp)
	sw $s6, 76($sp)
	sw $s7, 80($sp)
	sw $t8, 84($sp)
	sw $t9, 88($sp)

	# Increment stack counter.
	addi $sp, $sp, 92

	# Put the function address in $ra and
	# pass control over to function using jr.
	add $ra, $0, $v0 

jr $ra

# --------------------------------------------------------------------------------
# 	ReturnFunction: Pops the last frame of the stack, restores registers and
#			returns control to where the last function was called from.
# --------------------------------------------------------------------------------
ReturnFunction:

	# Decrement stack counter.
	subi $sp, $sp, 92	

	# Pop return address from stack.
	lw $ra, 0($sp)

	# Pop registers from stack.
	lw $a0, 4($sp)
	lw $a1, 8($sp)
	lw $a2, 12($sp)
	lw $a3, 16($sp)
	lw $t0, 20($sp)
	lw $t1, 24($sp)
	lw $t2, 28($sp)
	lw $t3, 32($sp)
	lw $t4, 36($sp)
	lw $t5, 40($sp)
	lw $t6, 44($sp)
	lw $t7, 48($sp)
	lw $s0, 52($sp)
	lw $s1, 56($sp)
	lw $s2, 60($sp)
	lw $s3, 64($sp)
	lw $s4, 68($sp)
	lw $s5, 72($sp)
	lw $s6, 76($sp)
	lw $s7, 80($sp)
	lw $t8, 84($sp)
	lw $t9, 88($sp)

	# Return address is in $ra, so just jr and
	# return control to the caller.

jr $ra
