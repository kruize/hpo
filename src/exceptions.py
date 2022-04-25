class Error(Exception):
    """Base class for other exceptions"""
    pass

class ExperimentNotFoundError(Error):
    """Raised when the input value is too small"""
    pass