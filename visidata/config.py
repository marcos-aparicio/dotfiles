from visidata import date as vd_date

def naive_date_type(s):
    d = vd_date(s)
    return d.replace(tzinfo=None) if d else None

options.clean_names = True

