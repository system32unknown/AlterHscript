package alterhscript;

import alterhscript.utils.Ansi;

/**
 * Declares the severity of an error,
 * adds a little prefix to printing showing which kind of failure it is
**/
enum ErrorSeverity {
	NONE;
	WARN;
	ERROR;
	FATAL;
}

class ErrorSeverityTools {
	public static function getPrefix(severity:ErrorSeverity):String {
		return switch (severity) {
			case NONE: "";
			case null: "UNKNOWN";
			case _: Type.enumConstructor(severity);
		}
	}

	public static function getColor(severity:ErrorSeverity):AnsiColor {
		return switch (severity) {
			case NONE: AnsiColor.DEFAULT;
			case WARN: AnsiColor.YELLOW;
			case ERROR: AnsiColor.RED;
			case FATAL: AnsiColor.RED;
			case _: AnsiColor.DEFAULT;
		}
	}
}
