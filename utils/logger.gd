# utils/logger.gd
extends Node
class_name Logger

enum LogLevel { DEBUG, INFO, WARNING, ERROR, NONE }

static var current_level: LogLevel = LogLevel.INFO
static var include_timestamp: bool = true
static var include_caller: bool = true
static var log_to_file: bool = false
static var log_file_path: String = "user://game.log"
static var file: FileAccess


static func _static_init():
    if log_to_file:
        file = FileAccess.open(log_file_path, FileAccess.WRITE)
        if file:
            file.store_line("=== LOG STARTED === " + Time.get_datetime_string_from_system())


static func debug(message: String, context: String = ""):
    if current_level <= LogLevel.DEBUG:
        _log("DEBUG", message, context)


static func info(message: String, context: String = ""):
    if current_level <= LogLevel.INFO:
        _log("INFO", message, context)


static func warning(message: String, context: String = ""):
    if current_level <= LogLevel.WARNING:
        _log("WARNING", message, context)


static func error(message: String, context: String = ""):
    if current_level <= LogLevel.ERROR:
        _log("ERROR", message, context)


static func _log(level: String, message: String, context: String):
    var parts = []
    
    if include_timestamp:
        var time = Time.get_datetime_dict_from_system()
        var timestamp = "%02d:%02d:%02d" % [time.hour, time.minute, time.second]
        parts.append("[" + timestamp + "]")
    
    parts.append("[" + level + "]")
    
    if context and include_caller:
        parts.append("[" + context + "]")
    
    parts.append(message)
    
    var output = " ".join(parts)
    print(output)
    
    if log_to_file and file:
        file.store_line(output)
        file.flush()


static func set_level(level: LogLevel):
    current_level = level
    info("Log level set to " + str(level), "Logger")


static func enable_file_logging(enable: bool, path: String = "user://game.log"):
    log_to_file = enable
    if enable:
        log_file_path = path
        file = FileAccess.open(log_file_path, FileAccess.WRITE)
        if file:
            file.store_line("=== LOG STARTED === " + Time.get_datetime_string_from_system())
            info("File logging enabled: " + path, "Logger")
    else:
        if file:
            file.close()
            file = null