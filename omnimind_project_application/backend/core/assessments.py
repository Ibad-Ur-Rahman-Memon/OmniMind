"""core/assessments.py — Full standardized clinical assessments."""
import re
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple


@dataclass
class Question:
    id: str
    text: str
    options: List[str]
    scores: List[int]
    keywords: List[str]
    inferred_score: Optional[int] = None
    direct_score: Optional[int] = None
    confidence: float = 0.0

    def active_score(self) -> Optional[int]:
        return self.direct_score if self.direct_score is not None else self.inferred_score

    def option_label(self) -> Optional[str]:
        s = self.active_score()
        if s is None:
            return None
        try:
            return self.options[self.scores.index(s)]
        except (ValueError, IndexError):
            return None


@dataclass
class Assessment:
    name: str
    full_name: str
    domain: str
    questions: List[Question]
    severity_bands: List[Tuple[int, int, str, str]]
    interpretation: Dict[str, str]

    def total_score(self) -> int:
        return sum(q.active_score() or 0 for q in self.questions)

    def answered_count(self) -> int:
        return sum(1 for q in self.questions if q.active_score() is not None)

    def completion_pct(self) -> float:
        return self.answered_count() / len(self.questions) * 100

    def severity(self) -> Tuple[str, str]:
        s = self.total_score()
        for lo, hi, label, color in self.severity_bands:
            if lo <= s <= hi:
                return label, color
        return "Minimal", "#4CAF50"

    def interpretation_text(self) -> str:
        sev, _ = self.severity()
        return self.interpretation.get(sev, "Assessment in progress.")


def make_phq9() -> Assessment:
    opts = ["Not at all", "Several days", "More than half the days", "Nearly every day"]
    sc = [0, 1, 2, 3]
    return Assessment(
        name="PHQ-9",
        full_name="Patient Health Questionnaire-9",
        domain="Depression",
        questions=[
            Question(
                "PHQ1",
                "Little interest or pleasure in doing things?",
                opts,
                sc,
                [
                    "no interest",
                    "don't enjoy",
                    "lost interest",
                    "nothing fun",
                    "no pleasure",
                    "things i used to enjoy",
                    "pointless",
                    "can't enjoy",
                    "no interest",
                    "don't enjoy",
                    "nothing feels enjoyable",
                    "stopped enjoying",
                ],
            ),
            Question(
                "PHQ2",
                "Feeling down, depressed, or hopeless?",
                opts,
                sc,
                [
                    "depressed",
                    "down",
                    "hopeless",
                    "sad",
                    "low",
                    "blue",
                    "miserable",
                    "unhappy",
                    "gloomy",
                    "empty",
                    "feeling low",
                    "feel awful",
                    "feel empty",
                    "feeling empty",
                    "feel nothing",
                    "feel hopeless",
                    "hopeless",
                    "things won't get better",
                ],
            ),
            Question(
                "PHQ3",
                "Trouble falling or staying asleep, or sleeping too much?",
                opts,
                sc,
                [
                    "can't sleep",
                    "insomnia",
                    "sleeping too much",
                    "sleep problems",
                    "wake up",
                    "can't fall asleep",
                    "oversleeping",
                    "lying awake",
                    "sleep issues",
                    "can't sleep",
                    "not sleeping",
                    "no sleep",
                    "haven't slept",
                ],
            ),
            Question(
                "PHQ4",
                "Feeling tired or having little energy?",
                opts,
                sc,
                [
                    "tired",
                    "exhausted",
                    "no energy",
                    "fatigue",
                    "drained",
                    "worn out",
                    "sluggish",
                    "lethargic",
                    "always tired",
                    "so tired",
                    "no energy",
                    "exhausted",
                    "tired all the time",
                    "fatigue",
                ],
            ),
            Question(
                "PHQ5",
                "Poor appetite or overeating?",
                opts,
                sc,
                ["not eating", "no appetite", "overeating", "eating too much", "lost appetite", "not hungry", "skipping meals", "binge eating"],
            ),
            Question(
                "PHQ6",
                "Feeling bad about yourself, or that you are a failure?",
                opts,
                sc,
                [
                    "worthless",
                    "failure",
                    "let people down",
                    "bad about myself",
                    "guilt",
                    "ashamed",
                    "blame myself",
                    "useless",
                    "burden",
                    "hate myself",
                    "not good enough",
                ],
            ),
            Question(
                "PHQ7",
                "Trouble concentrating on things?",
                opts,
                sc,
                [
                    "can't concentrate",
                    "can't focus",
                    "distracted",
                    "mind wanders",
                    "foggy",
                    "can't think",
                    "trouble reading",
                    "can't remember",
                    "avoiding",
                    "avoiding everyone",
                    "locked myself",
                    "withdrawn",
                ],
            ),
            Question(
                "PHQ8",
                "Moving or speaking slowly, or being fidgety/restless?",
                opts,
                sc,
                ["moving slowly", "restless", "fidgety", "can't sit still", "agitated", "slowed down", "pacing"],
            ),
            Question(
                "PHQ9",
                "Thoughts of being better off dead or hurting yourself?",
                opts,
                sc,
                ["better off dead", "hurt myself", "thoughts of death", "don't want to be here", "end it all"],
            ),
        ],
        severity_bands=[
            (0, 4, "Minimal depression", "#4CAF50"),
            (5, 9, "Mild depression", "#8BC34A"),
            (10, 14, "Moderate depression", "#FFC107"),
            (15, 19, "Moderately severe", "#FF9800"),
            (20, 27, "Severe depression", "#F44336"),
        ],
        interpretation={
            "Minimal depression": "Minimal depressive symptoms. Monitor and provide psychoeducation.",
            "Mild depression": "Mild symptoms present. Watchful waiting and supportive counseling recommended.",
            "Moderate depression": "Moderate depression. CBT or structured therapy is recommended.",
            "Moderately severe": "Active treatment with pharmacotherapy and/or psychotherapy recommended.",
            "Severe depression": "Severe depression. Immediate professional evaluation required.",
        },
    )


def make_gad7() -> Assessment:
    opts = ["Not at all", "Several days", "More than half the days", "Nearly every day"]
    sc = [0, 1, 2, 3]
    return Assessment(
        name="GAD-7",
        full_name="Generalized Anxiety Disorder-7",
        domain="Anxiety",
        questions=[
            Question(
                "GAD1",
                "Feeling nervous, anxious, or on edge?",
                opts,
                sc,
                [
                    "nervous",
                    "anxious",
                    "on edge",
                    "worried",
                    "tense",
                    "uneasy",
                    "apprehensive",
                    "anxiety",
                    "heart races",
                    "racing heart",
                    "heart racing",
                    "feel nervous",
                    "nervous in class",
                    "get nervous",
                ],
            ),
            Question(
                "GAD2",
                "Not being able to stop or control worrying?",
                opts,
                sc,
                ["can't stop worrying", "can't control", "constant worry", "uncontrollable", "ruminating", "can't stop thinking", "always worrying", "can't stop thinking", "racing thoughts", "overthinking"],
            ),
            Question(
                "GAD3",
                "Worrying too much about different things?",
                opts,
                sc,
                ["worry about everything", "worry about many", "different worries", "all kinds of worries", "worry all the time", "worried about", "keep worrying", "constant worry"],
            ),
            Question(
                "GAD4",
                "Trouble relaxing?",
                opts,
                sc,
                ["can't relax", "always tense", "can't unwind", "never calm", "wound up", "can't switch off", "always on alert", "can't relax", "can't calm down", "tense"],
            ),
            Question(
                "GAD5",
                "Being so restless that it is hard to sit still?",
                opts,
                sc,
                ["restless", "can't sit still", "fidgety", "pacing", "jittery", "need to move"],
            ),
            Question(
                "GAD6",
                "Becoming easily annoyed or irritable?",
                opts,
                sc,
                ["irritable", "annoyed", "short tempered", "snapping at people", "easily frustrated", "agitated", "angry all the time"],
            ),
            Question(
                "GAD7",
                "Feeling afraid as if something awful might happen?",
                opts,
                sc,
                [
                    "something bad will happen",
                    "dread",
                    "doom",
                    "awful feeling",
                    "scared something will go wrong",
                    "fear of worst",
                    "catastrophe",
                    "scared",
                    "fear",
                    "afraid",
                    "something bad will happen",
                ],
            ),
        ],
        severity_bands=[
            (0, 4, "Minimal anxiety", "#4CAF50"),
            (5, 9, "Mild anxiety", "#8BC34A"),
            (10, 14, "Moderate anxiety", "#FFC107"),
            (15, 21, "Severe anxiety", "#F44336"),
        ],
        interpretation={
            "Minimal anxiety": "Minimal anxiety symptoms. Self-care and monitoring appropriate.",
            "Mild anxiety": "Mild anxiety present. Relaxation techniques and monitoring recommended.",
            "Moderate anxiety": "Moderate anxiety. CBT or structured therapy recommended.",
            "Severe anxiety": "Severe anxiety. Immediate professional evaluation required.",
        },
    )


def make_pss10() -> Assessment:
    opts = ["Never", "Almost never", "Sometimes", "Fairly often", "Very often"]
    fwd = [0, 1, 2, 3, 4]
    rev = [4, 3, 2, 1, 0]
    return Assessment(
        name="PSS-10",
        full_name="Perceived Stress Scale-10",
        domain="Stress",
        questions=[
            Question("PSS1", "Upset because of something unexpected?", opts, fwd, ["upset", "unexpected", "thrown off", "shocked"]),
            Question("PSS2", "Unable to control important things in life?", opts, fwd, ["out of control", "can't control", "helpless", "powerless", "out of control", "can't control", "falling behind"]),
            Question("PSS3", "Felt nervous and stressed?", opts, fwd, ["stressed", "under pressure", "overwhelmed", "too much stress", "overwhelmed", "feel overwhelmed", "too much", "stressed", "really stressed", "so much stress"]),
            Question("PSS4", "Felt confident to handle personal problems? (reversed)", opts, rev, ["confident", "can handle", "capable", "managing well"]),
            Question("PSS5", "Things were going your way? (reversed)", opts, rev, ["going well", "positive", "things are fine"]),
            Question("PSS6", "Unable to cope with what you had to do?", opts, fwd, ["can't cope", "too much", "can't manage", "falling apart", "can't cope", "don't know how to cope"]),
            Question("PSS7", "Able to control irritations? (reversed)", opts, rev, ["in control", "calm", "managing irritation"]),
            Question("PSS8", "Felt on top of things? (reversed)", opts, rev, ["on top", "ahead", "keeping up", "handling it"]),
            Question("PSS9", "Angered by things outside your control?", opts, fwd, ["angry", "frustrated", "out of my hands", "powerless anger"]),
            Question("PSS10", "Difficulties piling up so you cannot overcome them?", opts, fwd, ["piling up", "too many problems", "can't overcome", "everything at once", "drowning in problems"]),
        ],
        severity_bands=[
            (0, 13, "Low stress", "#4CAF50"),
            (14, 26, "Moderate stress", "#FFC107"),
            (27, 40, "High stress", "#F44336"),
        ],
        interpretation={
            "Low stress": "Perceived stress is low. Maintain healthy coping strategies.",
            "Moderate stress": "Moderate stress. Stress management techniques and lifestyle adjustments recommended.",
            "High stress": "High perceived stress. Professional support and structured stress management required.",
        },
    )


def make_spin() -> Assessment:
    opts = ["Not at all", "A little bit", "Somewhat", "Very much", "Extremely"]
    sc = [0, 1, 2, 3, 4]
    return Assessment(
        name="SPIN",
        full_name="Social Phobia Inventory",
        domain="Social Anxiety",
        questions=[
            Question("SPIN1", "Fear of people in authority?", opts, sc, ["afraid of authority", "scared of boss", "fear authority"]),
            Question("SPIN2", "Embarrassment causes avoiding things?", opts, sc, ["embarrassed", "embarrassment", "avoid because embarrassed", "too embarrassing", "humiliated", "humiliation", "turn red", "face goes red"]),
            Question("SPIN3", "Bothered by blushing in front of people?", opts, sc, ["blush", "blushing", "go red", "turn red", "face turns red", "face goes red", "blushes", "embarrassed", "humiliated", "humiliating", "humiliation", "till red", "embarrassing"]),
            Question("SPIN4", "Avoid talking to people you don't know?", opts, sc, ["avoid strangers", "can't talk to strangers", "afraid of new people"]),
            Question("SPIN5", "Being criticized scares you?", opts, sc, ["scared of criticism", "fear of judgment", "fear of judgement", "afraid of feedback", "scared what people think", "scared of being judged", "being judged", "people will judge", "judging me", "what people think", "think i am stupid", "think i'm stupid", "think im stupid"]),
            Question("SPIN6", "Avoid activities where center of attention?", opts, sc, ["avoid attention", "don't want to be noticed", "hate being center"]),
            Question("SPIN7", "Talking to strangers scares you?", opts, sc, ["talking to strangers", "scared of strangers", "can't approach people"]),
            Question("SPIN8", "Would do anything to avoid being criticized?", opts, sc, ["anything to avoid criticism", "can't be judged", "can't be judged", "won't be judged", "can't stand being judged"]),
            Question("SPIN9", "Heart palpitations when with other people?", opts, sc, ["heart racing around people", "heart races", "racing heart", "heart racing", "palpitations socially", "palpitations"]),
            Question(
                "SPIN10",
                "Avoid giving speeches or talks?",
                opts,
                sc,
                [
                    "avoid presentations",
                    "cancelled presentation",
                    "cancelled presentations",
                    "presentation",
                    "speaking in front",
                    "speak in front",
                    "public speaking",
                    "answer in class",
                    "speak in class",
                    "teacher asks questions",
                    "professor asks",
                    "teacher asked questions",
                    "professor asked",
                    "can't give speech",
                    "hate public speaking",
                ],
            ),
            Question("SPIN11", "Avoid being center of attention at all costs?", opts, sc, ["avoid center", "don't want spotlight", "hide from attention"]),
            Question(
                "SPIN12",
                "Avoid going to parties or gatherings?",
                opts,
                sc,
                [
                    "avoid parties",
                    "don't go to parties",
                    "skip social events",
                    "avoid gatherings",
                    "avoid class",
                    "avoiding class",
                    "skip class",
                    "avoid going",
                    "don't want to go",
                    "want to leave",
                    "avoid cafeteria",
                    "avoid sitting",
                    "stopped eating in cafeteria",
                ],
            ),
            Question("SPIN13", "Uncomfortable sweating when anxious around people?", opts, sc, ["sweat around people", "sweating socially", "sweating", "sweat"]),
            Question(
                "SPIN14",
                "Afraid when people might be watching you?",
                opts,
                sc,
                [
                    "afraid when watched",
                    "nervous when observed",
                    "can't perform watched",
                    "everyone is watching",
                    "everyone is watching me",
                    "everyone watching me",
                    "everyone staring",
                    "people watching",
                    "people watching me",
                    "under a microscope",
                    "everyone notices",
                    "being watched",
                    "afraid when everyone is watching",
                    "being judged",
                ],
            ),
            Question("SPIN15", "Embarrassment or looking stupid is among worst fears?", opts, sc, ["looking stupid", "stupid", "fear humiliation", "worst fear embarrassment", "worst fear", "embarrassing", "humiliating", "humiliated", "embarrassed"]),
            Question("SPIN16", "Avoid speaking to authority figures?", opts, sc, ["avoid authority", "can't talk to manager", "scared of superiors"]),
            Question("SPIN17", "Trembling or shaking in front of others?", opts, sc, ["trembling", "tremble", "shaking in public", "hands shake around people", "hands shake", "voice shakes", "freeze", "completely freeze", "go blank", "go completely blank"]),
        ],
        severity_bands=[
            (0, 20, "No social anxiety", "#4CAF50"),
            (21, 30, "Mild social anxiety", "#8BC34A"),
            (31, 40, "Moderate social anxiety", "#FFC107"),
            (41, 100, "Severe social anxiety", "#F44336"),
        ],
        interpretation={
            "No social anxiety": "No significant social anxiety detected.",
            "Mild social anxiety": "Mild social anxiety. Psychoeducation and gradual exposure recommended.",
            "Moderate social anxiety": "Moderate social anxiety. CBT with exposure therapy recommended.",
            "Severe social anxiety": "Severe social anxiety. Structured therapy and pharmacotherapy consideration.",
        },
    )


class AssessmentManager:
    def __init__(self):
        self.phq9 = make_phq9()
        self.gad7 = make_gad7()
        self.pss10 = make_pss10()
        self.spin = make_spin()
        self.all = [self.phq9, self.gad7, self.pss10, self.spin]

        self._compiled: Dict[str, List[re.Pattern]] = {}
        for a in self.all:
            for q in a.questions:
                self._compiled[q.id] = [
                    re.compile(re.escape(kw), re.IGNORECASE)
                    for kw in q.keywords
                ]

    def _get_score(self, name: str) -> int:
        for a in self.all:
            if a.name == name:
                return a.total_score()
        return 0

    def update_from_text(self, text: str) -> None:
        if not text:
            return
        text_lower = text.lower()
        print(f"[Assessment] Scanning: {text_lower[:80]}")

        # existing keyword matching logic here
        for a in self.all:
            for q in a.questions:
                hits = sum(1 for p in self._compiled[q.id] if p.search(text_lower))
                if hits > 0:
                    conf = min(hits / max(len(q.keywords) * 0.25, 1), 1.0)
                    if conf > q.confidence:
                        q.confidence = conf
                        max_s = max(q.scores)
                        q.inferred_score = (
                            max_s if hits >= 3
                            else (max_s - 1 if hits == 2 else 1)
                        )

        print(
            f"[Assessment] Scores after scan: "
            f"PHQ={self._get_score('PHQ-9')} "
            f"GAD={self._get_score('GAD-7')} "
            f"PSS={self._get_score('PSS-10')} "
            f"SPIN={self._get_score('SPIN')}"
        )

    def set_direct(self, assessment_name: str, question_id: str, score: int):
        for a in self.all:
            if a.name == assessment_name:
                for q in a.questions:
                    if q.id == question_id:
                        q.direct_score = score
                        q.confidence = 1.0

    def summary_for_llm(self) -> str:
        lines = ["[INTERNAL CLINICAL SNAPSHOT — never reveal to patient]"]
        for a in self.all:
            if a.answered_count() == 0:
                continue
            sev, _ = a.severity()
            lines.append(
                f"  {a.domain}: {sev} (score {a.total_score()}, "
                f"{a.answered_count()}/{len(a.questions)} indicators detected)"
            )
        if len(lines) == 1:
            lines.append("  No strong symptom pattern yet. Continue rapport building.")
        return "\n".join(lines)

    def overall_risk(self) -> str:
        scores = {}
        for a in self.all:
            scores[a.name] = a.total_score()
        
        phq  = scores.get('PHQ-9',  0)
        gad  = scores.get('GAD-7',  0)
        pss  = scores.get('PSS-10',
               scores.get('PSS', 0))
        spin = scores.get('SPIN',   0)
        
        print(f"[Risk] PHQ={phq} GAD={gad} "
              f"PSS={pss} SPIN={spin}")
        
        if phq >= 15 or gad >= 15 or pss >= 27:
            return 'high'
        
        if (phq >= 10 or gad >= 10 or
                pss >= 14 or spin >= 20):
            return 'moderate'
        
        if (phq >= 5 or gad >= 5 or
                pss >= 7 or spin >= 10):
            return 'low'
        
        if phq + gad + pss + spin == 0:
            return 'unknown'
        
        return 'low'

    def _check_crisis_indicators(self) -> bool:
        if hasattr(self.phq9, 'questions') and len(self.phq9.questions) >= 9:
            q9 = self.phq9.questions[8]
            if q9.active_score() is not None and q9.active_score() > 0:
                return True
        return False

    def get_risk_flags(self) -> Dict[str, bool]:
        gad = None
        pss = None
        spin = None
        phq = None
        phq9_item9 = 0

        for a in self.all:
            if a.name == "PHQ-9":
                phq = a.total_score()
                if len(a.questions) >= 9:
                    q9 = a.questions[8]
                    phq9_item9 = q9.active_score() or 0
            elif a.name == "GAD-7":
                gad = a.total_score()
            elif a.name in ["PSS-10", "PSS"]:
                pss = a.total_score()
            elif a.name == "SPIN":
                spin = a.total_score()

        return {
            "moderate_depression_risk": phq is not None and phq >= 10,
            "high_depression_risk": phq is not None and phq >= 15,
            "anxiety_risk": gad is not None and gad >= 10,
            "high_stress_risk": pss is not None and pss >= 27,
            "self_harm_risk": phq9_item9 > 0,
            "crisis_risk": self._check_crisis_indicators(),
        }

    def get_combined_risk_score(self) -> float:
        phq = self.phq9.total_score() if self.phq9 else 0
        gad = self.gad7.total_score() if self.gad7 else 0
        pss = self.pss10.total_score() if self.pss10 else 0
        spin = self.spin.total_score() if self.spin else 0

        max_phq = 27
        max_gad = 21
        max_pss = 40
        max_spin = 68

        norm_phq = phq / max_phq if max_phq > 0 else 0
        norm_gad = gad / max_gad if max_gad > 0 else 0
        norm_pss = pss / max_pss if max_pss > 0 else 0
        norm_spin = spin / max_spin if max_spin > 0 else 0

        weighted_sum = (norm_phq * 0.4) + (norm_gad * 0.3) + (norm_pss * 0.2) + (norm_spin * 0.1)
        return min(weighted_sum * 100, 100.0)

    def radar_data(self) -> Dict[str, float]:
        out: Dict[str, float] = {}
        for a in self.all:
            max_p = sum(max(q.scores) for q in a.questions)
            out[a.domain] = round(a.total_score() / max_p * 100, 1) if max_p else 0.0
        return out
