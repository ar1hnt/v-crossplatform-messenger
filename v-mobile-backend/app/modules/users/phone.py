def normalize_phone(phone_number: str) -> str:
    raw = "".join(char for char in phone_number if char.isdigit())
    if not raw:
        return ""
    if raw.startswith("8") and len(raw) == 11:
        return f"+7{raw[1:]}"
    if raw.startswith("7") and len(raw) == 11:
        return f"+{raw}"
    return f"+{raw}"
