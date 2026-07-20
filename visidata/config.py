import datetime
from visidata import vd, date as vd_date, options, Sheet

def naive_date(s=None):
    # mirror VisiData's `date`: no arg -> now, otherwise parse/accept `s`
    if s is None:
        d = vd_date()                    # now
    elif isinstance(s, datetime.datetime):
        d = s                            # already a date/datetime (e.g. a column value)
    else:
        d = vd_date(s)                   # parse a string
    return d.replace(tzinfo=None)        # strip tz -> naive

# register as its own type with a distinct icon (ñ) so it's not confused with `date` (@)
vd.addType(naive_date, 'ñ', '{}')

# zN sets the current column to naive_date (@ stays the built-in tz-aware date)
Sheet.addCommand('zN', 'type-naive-date', 'cursorCol.type = naive_date',
                 'set type of current column to naive_date (tz-naive)')

options.clean_names = True
