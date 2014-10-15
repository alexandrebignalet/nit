# This file is part of NIT ( http://www.nitlanguage.org ).
#
# This file is free software, which comes along with NIT.  This software is
# distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without  even  the implied warranty of  MERCHANTABILITY or  FITNESS FOR A
# PARTICULAR PURPOSE.  You can modify it is you want,  provided this header
# is kept unaltered, and a notification of the changes is added.
# You  are  allowed  to  redistribute it and sell it, alone or is a part of
# another product.

# Runtime library to loop around the main program for each line in file-name arguments
#
# Used by the interpreter when `-n` is used
module niti_runtime

redef class Sys
	redef fun run do
		if not args.is_empty then
			open_next_stream
		end
		loop
			read_next_line
			main
		end
	end

	# Read the next useful line from file-name arguments
	private fun read_next_line
	do
		if stdin.eof then
			open_next_stream
		end
		var line = stdin.read_line
		loop
			if not stdin.eof then break
			open_next_stream
			if not line.is_empty then break
			line = stdin.read_line
		end
		self.line = line
	end

	# Open the next file until there is no more arguments
	private fun open_next_stream
	do
		if args.is_empty then exit(0)
		stdin.close
		stdin = new IFStream.open(args.shift)
	end

	# The next line to process by the main program
	var line: String
end