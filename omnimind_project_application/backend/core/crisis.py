import re
from dataclasses import dataclass
from typing import Optional

@dataclass
class CrisisResult:
    detected: bool
    message: str
    crisis_type: str = "none"

# Suicide / self-harm keywords
SUICIDE_KEYWORDS = [
    "kill myself", "end my life", "take my life",
    "want to die", "better off dead",
    "everyone better off without me",
    "thinking about suicide", "suicidal",
    "hurt myself", "harm myself", "cut myself",
    "no reason to live", "don't want to live",
    "dont want to live", "want to end it all",
    "end it all", "no point in living",
    "life has no meaning", "wish i was dead",
    "wish i were dead", "rather be dead",
    "thinking of suicide", "commit suicide",
    "ending my life", "take my own life",
    "i want to die",
]

# Violence / harm to others keywords  
VIOLENCE_KEYWORDS = [
    "kill my brother", "kill my sister",
    "kill my father", "kill my mother",
    "kill my wife", "kill my husband",
    "kill my son", "kill my daughter",
    "kill my friend", "kill my teacher",
    "kill my boss", "kill other",
    "kill my other", "feel i kill",
    "want to kill someone", "going to kill",
    "hurt my family", "harm my family",
    "want to hurt someone", "want to harm",
    "thoughts of killing", "thinking of killing",
    "murder someone", "attack someone",
]

# General crisis keywords
GENERAL_CRISIS_KEYWORDS = [
    "no sense of living", "no reason to be alive",
    "life is not worth living",
    "cannot take this anymore",
    "can't take this anymore",
    "cannot take this pain",
    "don't want to be here anymore",
    "dont want to be here",
    "no will to live", "lost will to live",
    "give up on life", "giving up on life",
]

SUICIDE_RESPONSE = """I'm deeply concerned about \
what you just shared, and I want you to know — \
you are not alone in this moment. What you're \
feeling right now is serious, and you deserve \
real, immediate support from someone trained \
to help.

Please reach out to a crisis helpline right now:

- Pakistan: Umang: 0317-4288665
- Pakistan: Rozan: 051-2890505
- USA: 988 Suicide & Crisis Lifeline — call/text 988
- UK: Samaritans — 116 123 (free, 24/7)
- India: iCall — 9152987821
- International: https://www.findahelpline.com

If you are in immediate danger, please call \
emergency services (115 in Pakistan · 911 in \
USA · 999 in UK).

I'm still here for you. Whenever you're ready \
to talk, I'm listening. 💙"""

VIOLENCE_RESPONSE = """What you're sharing tells \
me you're carrying an enormous amount of pain \
right now. Thoughts of hurting others are a \
sign that you need immediate support — \
not judgment.

Please reach out right now:
- Pakistan Umang helpline: 0317-4288665
- Pakistan emergency services: 115
- International: https://www.findahelpline.com

You don't have to carry this alone. \
I'm here with you."""

GENERAL_CRISIS_RESPONSE = """It sounds like \
you're in a lot of pain right now, and I'm \
really glad you're talking to me. What you're \
feeling is serious and you deserve support.

Please reach out to someone who can help:
- Pakistan: Umang: 0317-4288665
- Emergency: 115
- International: https://www.findahelpline.com

You matter and things can get better \
with the right support. I'm here with you."""

def check_crisis(text: str) -> CrisisResult:
    if not text:
        return CrisisResult(
            detected=False, 
            message="",
            crisis_type="none"
        )
    
    text_lower = text.lower().strip()
    
    # Check suicide FIRST (before violence)
    # because "kill myself" contains "kill"
    # but is suicide not violence
    for keyword in SUICIDE_KEYWORDS:
        if keyword in text_lower:
            return CrisisResult(
                detected=True,
                message=SUICIDE_RESPONSE,
                crisis_type="suicide"
            )
    
    # Check violence second
    for keyword in VIOLENCE_KEYWORDS:
        if keyword in text_lower:
            return CrisisResult(
                detected=True,
                message=VIOLENCE_RESPONSE,
                crisis_type="violence"
            )
    
    # Check general crisis third
    for keyword in GENERAL_CRISIS_KEYWORDS:
        if keyword in text_lower:
            return CrisisResult(
                detected=True,
                message=GENERAL_CRISIS_RESPONSE,
                crisis_type="crisis"
            )
    
    return CrisisResult(
        detected=False,
        message="",
        crisis_type="none"
    )

