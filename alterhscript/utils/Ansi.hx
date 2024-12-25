package alterhscript.utils;

#if (haxe_ver < 4.3) @:enum #else enum #end

abstract AnsiColor(Int) {
	final BLACK:AnsiColor = 0;
	final RED:AnsiColor = 1;
	final GREEN:AnsiColor = 2;
	final YELLOW:AnsiColor = 3;
	final BLUE:AnsiColor = 4;
	final MAGENTA:AnsiColor = 5;
	final CYAN:AnsiColor = 6;
	final WHITE:AnsiColor = 7;
	final DEFAULT:AnsiColor = 9;
	final ORANGE:AnsiColor = 216;
	final DARK_ORANGE:AnsiColor = 215;
	final ORANGE_BRIGHT:AnsiColor = 208;
}

#if (haxe_ver < 4.3) @:enum #else enum #end

abstract AnsiTextAttribute(Int) {
	/**
	 * All colors/text-attributes off
	 */
	final RESET:AnsiTextAttribute = 0;
	final INTENSITY_BOLD:AnsiTextAttribute = 1;

	/**
	 * Not widely supported.
	 */
	final INTENSITY_FAINT:AnsiTextAttribute = 2;

	/**
	 * Not widely supported.
	 */
	final ITALIC:AnsiTextAttribute = 3;
	final UNDERLINE_SINGLE:AnsiTextAttribute = 4;
	final BLINK_SLOW:AnsiTextAttribute = 5;

	/**
	 * Not widely supported.
	 */
	final BLINK_FAST:AnsiTextAttribute = 6;
	final NEGATIVE:AnsiTextAttribute = 7;

	/**
	 * Not widely supported.
	 */
	final HIDDEN:AnsiTextAttribute = 8;

	/**
	 * Not widely supported.
	 */
	final STRIKETHROUGH:AnsiTextAttribute = 9;

	/**
	 * Not widely supported.
	 */
	final UNDERLINE_DOUBLE:AnsiTextAttribute = 21;
	final INTENSITY_OFF:AnsiTextAttribute = 22;
	final ITALIC_OFF:AnsiTextAttribute = 23;
	final UNDERLINE_OFF:AnsiTextAttribute = 24;
	final BLINK_OFF:AnsiTextAttribute = 25;
	final NEGATIVE_OFF:AnsiTextAttribute = 27;
	final HIDDEN_OFF:AnsiTextAttribute = 28;
	final STRIKTHROUGH_OFF:AnsiTextAttribute = 29;
}

class Ansi implements AlterUsingClass {
	/**
	 * ANSI escape sequence header
	 */
	public static inline final ESC = "\x1B[";

	inline public static function reset(str:String):String
		return str + ESC + "0m";

	/**
	 * sets the given text attribute
	 */
	inline public static function attr(str:String, attr:AnsiTextAttribute):String
		return ESC + (attr) + "m" + str;

	/**
	 * set the text background color
	 *
	 * <pre><code>
	 * >>> Ansi.bg(RED) == "\x1B[41m"
	 * </code></pre>
	 */
	inline public static function bg(str:String, color:AnsiColor):String
		return ESC + "4" + color + "m" + str;

	/**
	 * Clears the screen and moves the cursor to the home position
	 */
	inline public static function clearScreen():String
		return ESC + "2Jm";

	/**
	 * Clear all characters from current position to the end of the line including the character at the current position
	 */
	inline public static function clearLine():String
		return ESC + "Km";

	/**
	 * set the text foreground color
	 *
	 * <pre><code>
	 * >>> Ansi.fg(RED) == "\x1B[31m"
	 * </code></pre>
	 */
	inline public static function fg(str:String, color:AnsiColor):String
		return ESC + "38;5;" + color + "m" + str;

	static var colorSupported:Null<Bool> = null;

	public static function stripColor(output:String):String {
		#if sys
		if (colorSupported == null) {
			var term = Sys.getEnv("TERM");

			if (term == "dumb") {
				colorSupported = false;
			} else {
				if (colorSupported != true && term != null) {
					colorSupported = ~/(?i)-256(color)?$/.match(term)
						|| ~/(?i)^screen|^xterm|^vt100|^vt220|^rxvt|color|ansi|cygwin|linux/.match(term);
				}

				if (colorSupported != true) {
					colorSupported = Sys.getEnv("TERM_PROGRAM") == "iTerm.app"
						|| Sys.getEnv("TERM_PROGRAM") == "Apple_Terminal"
						|| Sys.getEnv("COLORTERM") != null
						|| Sys.getEnv("ANSICON") != null
						|| Sys.getEnv("ConEmuANSI") != null
						|| Sys.getEnv("WT_SESSION") != null;
				}
			}
		}

		if (colorSupported) {
			return output;
		}
		#end
		return ~/\x1b\[[^m]*m/g.replace(output, "");
	}
}
