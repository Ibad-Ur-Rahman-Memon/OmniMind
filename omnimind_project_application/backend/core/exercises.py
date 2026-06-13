"""core/exercises.py — Six evidence-based CBT exercises."""
from dataclasses import dataclass
from typing import List, Dict


@dataclass
class Exercise:
    id: str
    name: str
    domains: List[str]
    tagline: str
    duration_min: int
    steps: List[str]
    intro_message: str
    post_prompt: str
    evidence: str


EXERCISES: Dict[str, Exercise] = {
    "breathing_478": Exercise(
        id="breathing_478",
        name="4-7-8 Breathing",
        domains=["anxiety", "stress", "panic"],
        tagline="Activates your body's natural calm-down response",
        duration_min=2,
        steps=[
            "Sit comfortably. Place one hand on your chest and one on your belly.",
            "Breathe in quietly through your nose for **4 counts**. Feel your belly expand.",
            "Hold your breath completely for **7 counts**. Stay still.",
            "Exhale fully through your mouth, making a whoosh sound, for **8 counts**.",
            "That is one cycle. Repeat for **3 more cycles** — 4 total.",
            "After the last cycle, breathe normally. Notice how your body feels right now.",
        ],
        intro_message=(
            "I'd like to share a breathing technique that can calm your nervous system right now. "
            "It's called 4-7-8 breathing — it activates your parasympathetic nervous system, "
            "your body's built-in braking system. It takes about 2 minutes. "
            "Shall we do it together?"
        ),
        post_prompt="How did that feel? What did you notice in your body during and after?",
        evidence="Gerritsen & Band (2018), Frontiers in Human Neuroscience",
    ),
    "grounding_54321": Exercise(
        id="grounding_54321",
        name="5-4-3-2-1 Grounding",
        domains=["anxiety", "panic", "dissociation", "stress"],
        tagline="Anchors you firmly in the present moment using your senses",
        duration_min=3,
        steps=[
            "Look around you. Name **5 things you can SEE** right now — say them quietly.",
            "Touch something nearby. Notice **4 things you can FEEL** — feet on floor, clothes on skin.",
            "Listen carefully. Identify **3 things you can HEAR** — even faint background sounds.",
            "Notice **2 things you can SMELL** — or two scents you love and can imagine.",
            "Notice **1 thing you can TASTE** right now.",
            "Take one slow breath. Notice how much more present you feel in this moment.",
        ],
        intro_message=(
            "When anxiety pulls us into 'what if' thoughts, grounding brings us back to right now. "
            "I'll guide you through 5-4-3-2-1 — it uses your five senses as an anchor. "
            "Takes about 3 minutes. Ready to try it?"
        ),
        post_prompt="How are you feeling now compared to before? Which sense felt most grounding?",
        evidence="DBT Skills Training, Linehan (1993); Trauma-Focused CBT",
    ),
    "thought_record": Exercise(
        id="thought_record",
        name="Thought Record",
        domains=["depression", "anxiety", "negative_thinking"],
        tagline="Examines and gently challenges automatic negative thoughts",
        duration_min=8,
        steps=[
            "**SITUATION:** Describe the situation that triggered the distressing thought. Facts only — where, what happened?",
            "**AUTOMATIC THOUGHT:** What exact thought went through your mind? Write it word for word.",
            "**EMOTIONS:** What emotions did you feel? Rate intensity 0–100% for each.",
            "**EVIDENCE FOR:** What real facts support this thought being completely true?",
            "**EVIDENCE AGAINST:** What facts suggest it might not be fully accurate or is exaggerated?",
            "**BALANCED THOUGHT:** Write a more realistic version that accounts for both sides.",
            "**RE-RATE:** How intense are those emotions NOW (0–100%)? What's changed?",
        ],
        intro_message=(
            "One of the most powerful tools in psychology is called a thought record. "
            "It helps us slow down automatic thoughts and examine them like a scientist — "
            "looking at the actual evidence. Can you think of a specific situation recently "
            "that felt distressing? We'll use it as our example."
        ),
        post_prompt="How does the balanced thought feel compared to the original? What did you discover?",
        evidence="Beck (1979) — foundational CBT, strong evidence for depression and anxiety",
    ),
    "behavioral_activation": Exercise(
        id="behavioral_activation",
        name="Behavioral Activation",
        domains=["depression", "low_mood", "withdrawal"],
        tagline="Breaks the depression withdrawal cycle through small, meaningful actions",
        duration_min=10,
        steps=[
            "Think of **3 activities you used to enjoy** before feeling low — even small ones. A walk, cooking, calling someone.",
            "For each, rate: (a) Expected pleasure now 0–10, and (b) Effort needed 0–10.",
            "Choose the activity with **lowest effort and reasonable pleasure** as your starting point.",
            "Schedule it for a **specific time in the next 48 hours** — 'Tuesday 4pm', not 'sometime'.",
            "Make it **very small**: not 'go for a run' but 'put on shoes and walk to the gate'.",
            "After you do it, rate how you **actually felt** 0–10. Notice if the mood followed.",
        ],
        intro_message=(
            "Depression tells us to wait until we feel motivated before doing things. "
            "But research shows action comes first — the mood follows the doing, not the other way around. "
            "I'd like to help you plan one small meaningful activity for the next 48 hours. "
            "What are some things you used to enjoy, even a little?"
        ),
        post_prompt="How likely are you to actually do this (0–10)? What might get in the way?",
        evidence="Lewinsohn (1974); Martell et al. (2010) — evidence-based for depression",
    ),
    "pmr": Exercise(
        id="pmr",
        name="Progressive Muscle Relaxation",
        domains=["stress", "anxiety", "tension", "somatic"],
        tagline="Releases physical tension stored in your body, muscle by muscle",
        duration_min=5,
        steps=[
            "Find a comfortable position — sitting or lying. Close your eyes if comfortable.",
            "**FEET:** Curl your toes tightly for 5 seconds… then release completely. Feel the difference.",
            "**CALVES:** Tense for 5 seconds… release. Notice the warmth.",
            "**THIGHS & STOMACH:** Squeeze for 5 seconds… release fully.",
            "**HANDS & ARMS:** Clench both fists tightly for 5 seconds… open wide, release.",
            "**SHOULDERS:** Shrug up to your ears for 5 seconds… drop them completely. Release.",
            "**FACE:** Scrunch all facial muscles tightly for 5 seconds… release everything.",
            "Take 3 slow breaths. Scan your body head to toe — notice the warmth and heaviness.",
            "Stay with this feeling for a moment. Your body knows how to relax.",
        ],
        intro_message=(
            "Stress and anxiety often live physically in the body — tight shoulders, clenched jaw, "
            "a knotted stomach. Progressive Muscle Relaxation teaches your body the difference "
            "between tension and relaxation. Takes about 5 minutes. "
            "Can you find a comfortable position right now?"
        ),
        post_prompt="How does your body feel now? Which muscle group held the most tension?",
        evidence="Jacobson (1938) — validated across anxiety, stress, chronic pain",
    ),
    "worry_postponement": Exercise(
        id="worry_postponement",
        name="Scheduled Worry Time",
        domains=["anxiety", "rumination", "chronic_worry"],
        tagline="Contains worry to a specific daily window instead of all day",
        duration_min=5,
        steps=[
            "Choose a **specific 15-minute window** each day as your 'worry time' (e.g., 5:00–5:15 PM). Never before bed.",
            "When worry arises **outside** that window, write it down briefly and say: 'I'll think about this at 5pm.'",
            "When your worry window arrives, **actively engage** with your worry list for the full 15 minutes.",
            "For each worry ask: **'Can I do something about this?'** If yes — write one small action. If no — practice acceptance.",
            "When 15 minutes ends, **close the list and return** to your day. The time is up.",
        ],
        intro_message=(
            "When we worry all day, it exhausts us without solving anything. "
            "Scheduled Worry Time contains worries to a specific window rather than fighting them. "
            "Research shows this significantly reduces overall anxiety. "
            "Shall we set your worry window together right now?"
        ),
        post_prompt="What time of day would work best for your worry window? What do you think about trying this tomorrow?",
        evidence="Borkovec et al. (1983) — evidence-based for Generalized Anxiety Disorder",
    ),
}


def get_exercises_for_domain(domain: str) -> List[Exercise]:
    return [e for e in EXERCISES.values() if domain.lower() in [d.lower() for d in e.domains]]
