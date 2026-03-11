"""
AI-Driven Adaptive Quiz Engine for Disaster Preparedness E-Learning.

Uses a weighted question-selection algorithm that adapts to each learner's
weak areas (phases they score poorly on) and progressively increases
difficulty as mastery improves.  Scoring uses numpy for efficient
computation of knowledge-gap weights.
"""

import random
from typing import Dict, List, Optional, Tuple

import numpy as np

# ── Question bank ────────────────────────────────────────────────────────────
# Each question has: text, options (A-D), correct answer key, phase
# (before/during/after), difficulty (1=easy, 2=medium, 3=hard), and
# explanation shown after answering.

_QuestionDict = Dict[str, object]

QUESTION_BANK: Dict[str, List[_QuestionDict]] = {
    # ── FLOOD ────────────────────────────────────────────────────────────
    "flood": [
        # Before — easy
        {
            "text": "How much water per person per day should you prepare in an emergency kit?",
            "options": {"A": "1 litre", "B": "3 litres", "C": "500 ml", "D": "5 litres"},
            "answer": "B",
            "phase": "before",
            "difficulty": 1,
            "explanation": "The recommended amount is 3 litres per person per day for drinking and basic hygiene.",
        },
        {
            "text": "Where should you store important documents before a flood?",
            "options": {"A": "Under the bed", "B": "In a drawer", "C": "In a sealed waterproof bag", "D": "In the car"},
            "answer": "C",
            "phase": "before",
            "difficulty": 1,
            "explanation": "A sealed waterproof bag protects documents from water damage during evacuations.",
        },
        {
            "text": "What is the FIRST thing you should identify in your flood preparedness plan?",
            "options": {"A": "Nearest restaurant", "B": "Two evacuation routes from your home", "C": "Social media groups", "D": "Insurance agent number"},
            "answer": "B",
            "phase": "before",
            "difficulty": 2,
            "explanation": "Knowing at least two evacuation routes ensures you have alternatives if one is blocked.",
        },
        {
            "text": "Which household maintenance task helps reduce flood risk around your home?",
            "options": {"A": "Painting walls", "B": "Clearing drains and gutters", "C": "Mowing the lawn", "D": "Installing curtains"},
            "answer": "B",
            "phase": "before",
            "difficulty": 2,
            "explanation": "Clear drains and gutters allow rainwater to flow away, reducing local flooding.",
        },
        {
            "text": "How often should a family review and practise their flood evacuation plan?",
            "options": {"A": "Every 5 years", "B": "Only once", "C": "At least twice a year", "D": "Only when it rains"},
            "answer": "C",
            "phase": "before",
            "difficulty": 3,
            "explanation": "Regular practice (at least twice a year) ensures everyone remembers routes and meeting points.",
        },
        # During — easy
        {
            "text": "How deep must floodwater be before it can knock an adult off their feet?",
            "options": {"A": "1 metre", "B": "15 centimetres of moving water", "C": "50 cm", "D": "Only waist-deep water"},
            "answer": "B",
            "phase": "during",
            "difficulty": 1,
            "explanation": "Just 15 cm (6 inches) of fast-moving floodwater can knock a person down.",
        },
        {
            "text": "What should you do if floodwater starts entering your home?",
            "options": {"A": "Wait for it to stop", "B": "Try to drain it with buckets", "C": "Move to the highest point available", "D": "Open all windows"},
            "answer": "C",
            "phase": "during",
            "difficulty": 1,
            "explanation": "Moving to the highest point (upper floor, rooftop) keeps you above rising water.",
        },
        {
            "text": "Before evacuating during a flood, what utilities should you turn off if safe to do so?",
            "options": {"A": "WiFi and TV", "B": "Electricity, gas, and water mains", "C": "Only the lights", "D": "The air conditioning only"},
            "answer": "B",
            "phase": "during",
            "difficulty": 2,
            "explanation": "Turning off electricity, gas, and water at the mains prevents electrocution, fires, and contamination.",
        },
        {
            "text": "Why should you avoid contact with floodwater?",
            "options": {"A": "It is always cold", "B": "It may contain sewage and chemicals", "C": "It is salty", "D": "It has strong currents only"},
            "answer": "B",
            "phase": "during",
            "difficulty": 2,
            "explanation": "Floodwater often contains sewage, chemicals, and bacteria that cause serious illness.",
        },
        {
            "text": "During a flood, an evacuation order is issued. What is the correct response?",
            "options": {"A": "Wait to see if it gets worse", "B": "Leave immediately — do not wait for water to enter", "C": "Call a friend first", "D": "Gather all valuables before leaving"},
            "answer": "B",
            "phase": "during",
            "difficulty": 3,
            "explanation": "Evacuation orders should be followed immediately. Delays risk lives.",
        },
        # After — easy
        {
            "text": "When is it safe to return home after a flood?",
            "options": {"A": "After the rain stops", "B": "After authorities declare the area safe", "C": "Next morning", "D": "When your neighbours return"},
            "answer": "B",
            "phase": "after",
            "difficulty": 1,
            "explanation": "Only return when authorities confirm it is safe — structural damage and contamination may linger.",
        },
        {
            "text": "What should you wear when cleaning up after a flood?",
            "options": {"A": "Sandals and shorts", "B": "Normal clothes", "C": "Gloves, boots, and masks", "D": "Only a raincoat"},
            "answer": "C",
            "phase": "after",
            "difficulty": 1,
            "explanation": "Protective gear (gloves, boots, masks) guards against bacteria, silt, and chemicals left by floodwater.",
        },
        {
            "text": "Should you eat food that was in contact with floodwater?",
            "options": {"A": "Yes, if it looks fine", "B": "Yes, after washing it", "C": "No, discard it", "D": "Only canned food is okay"},
            "answer": "C",
            "phase": "after",
            "difficulty": 2,
            "explanation": "Any food that touched floodwater must be discarded — contamination is not always visible.",
        },
        {
            "text": "Before turning the electricity back on after a flood, you should:",
            "options": {"A": "Flip the main switch yourself", "B": "Wait 24 hours", "C": "Have a qualified electrician inspect wiring first", "D": "Just try it and see"},
            "answer": "C",
            "phase": "after",
            "difficulty": 3,
            "explanation": "Water-damaged wiring can cause electrocution or fire. A qualified electrician must inspect it first.",
        },
    ],

    # ── LANDSLIDE ────────────────────────────────────────────────────────
    "landslide": [
        {
            "text": "Which is a common early warning sign of a landslide?",
            "options": {"A": "Birds singing", "B": "New cracks in walls or ground", "C": "Lower electricity bills", "D": "Clear skies"},
            "answer": "B",
            "phase": "before",
            "difficulty": 1,
            "explanation": "New cracks in walls, ground, or pavement indicate ground movement — a precursor to landslides.",
        },
        {
            "text": "Where should your evacuation route lead during a landslide threat?",
            "options": {"A": "Towards the valley", "B": "Away from slopes and valleys", "C": "Downhill", "D": "Towards the river"},
            "answer": "B",
            "phase": "before",
            "difficulty": 1,
            "explanation": "Move away from slopes and valleys where debris flows can funnel.",
        },
        {
            "text": "Which agency classifies slope risk levels in Malaysia?",
            "options": {"A": "TNB", "B": "JMG (Jabatan Mineral dan Geosains)", "C": "DBKL", "D": "Pos Malaysia"},
            "answer": "B",
            "phase": "before",
            "difficulty": 2,
            "explanation": "JMG (Department of Mineral and Geoscience) classifies and monitors slope stability in Malaysia.",
        },
        {
            "text": "If you hear rumbling sounds and see debris moving, you should:",
            "options": {"A": "Take photos", "B": "Evacuate uphill or to stable ground immediately", "C": "Go back inside", "D": "Drive towards it"},
            "answer": "B",
            "phase": "during",
            "difficulty": 1,
            "explanation": "Evacuate immediately uphill or to stable ground — never try to cross a debris flow.",
        },
        {
            "text": "If you are indoors and cannot escape a landslide, what should you do?",
            "options": {"A": "Stand near a window", "B": "Run to the basement", "C": "Curl under a sturdy table and protect your head", "D": "Open the front door"},
            "answer": "C",
            "phase": "during",
            "difficulty": 2,
            "explanation": "Taking cover under a sturdy table protects you from falling debris if escape is not possible.",
        },
        {
            "text": "After a landslide, why should you stay away from the slide area?",
            "options": {"A": "It is dirty", "B": "Secondary slides are common", "C": "There is no reason", "D": "Authorities want silence"},
            "answer": "B",
            "phase": "after",
            "difficulty": 1,
            "explanation": "Further slides frequently follow the first, making the area dangerous for hours or days.",
        },
        {
            "text": "What should you watch for after a landslide blocks a river?",
            "options": {"A": "Fish jumping", "B": "Flooding upstream of the blockage", "C": "Clear water", "D": "Nothing"},
            "answer": "B",
            "phase": "after",
            "difficulty": 3,
            "explanation": "A landslide dam can cause upstream flooding and may burst, releasing a devastating flood.",
        },
    ],

    # ── EARTHQUAKE ───────────────────────────────────────────────────────
    "earthquake": [
        {
            "text": "What are the three actions of earthquake response?",
            "options": {"A": "Run, Hide, Fight", "B": "Stop, Look, Listen", "C": "Drop, Cover, Hold On", "D": "Duck, Roll, Stand"},
            "answer": "C",
            "phase": "during",
            "difficulty": 1,
            "explanation": "DROP to hands and knees, take COVER under sturdy furniture, and HOLD ON until shaking stops.",
        },
        {
            "text": "During an earthquake, why should you stay indoors?",
            "options": {"A": "It is more comfortable", "B": "Most injuries occur from falling debris when running outside", "C": "The door might lock", "D": "Because of noise"},
            "answer": "B",
            "phase": "during",
            "difficulty": 1,
            "explanation": "Running outside exposes you to falling glass, bricks, and other debris — a major cause of earthquake injuries.",
        },
        {
            "text": "What should you keep beside your bed for a nighttime earthquake?",
            "options": {"A": "A book", "B": "Shoes and a torch", "C": "A phone charger only", "D": "A glass of water"},
            "answer": "B",
            "phase": "before",
            "difficulty": 1,
            "explanation": "Shoes protect your feet from broken glass and a torch helps you navigate in the dark.",
        },
        {
            "text": "After an earthquake, what should you expect?",
            "options": {"A": "Rain", "B": "Power surges", "C": "Aftershocks", "D": "Clear weather"},
            "answer": "C",
            "phase": "after",
            "difficulty": 1,
            "explanation": "Aftershocks frequently follow the main earthquake and can cause additional damage.",
        },
        {
            "text": "If you smell gas after an earthquake, you should:",
            "options": {"A": "Light a candle to check", "B": "Leave immediately and call the fire department", "C": "Ignore it", "D": "Turn on the stove to test"},
            "answer": "B",
            "phase": "after",
            "difficulty": 2,
            "explanation": "A gas leak is extremely dangerous. Leave immediately, do not create sparks, and call emergency services.",
        },
        {
            "text": "How can you earthquake-proof heavy furniture at home?",
            "options": {"A": "Move it to the centre", "B": "Secure it to walls with brackets or straps", "C": "Place it near windows", "D": "Stack items on top"},
            "answer": "B",
            "phase": "before",
            "difficulty": 2,
            "explanation": "Securing heavy furniture to walls prevents it from toppling during shaking.",
        },
        {
            "text": "In Malaysia, which region has moderate seismic risk?",
            "options": {"A": "Kuala Lumpur", "B": "Penang", "C": "Sabah (especially Ranau)", "D": "Johor"},
            "answer": "C",
            "phase": "before",
            "difficulty": 3,
            "explanation": "Sabah, particularly the Ranau area, has moderate seismic activity due to tectonic faults.",
        },
    ],

    # ── STORM ────────────────────────────────────────────────────────────
    "storm": [
        {
            "text": "Before a storm, what should you do with outdoor furniture?",
            "options": {"A": "Leave it outside", "B": "Secure or bring it indoors", "C": "Move it to the roof", "D": "Donate it"},
            "answer": "B",
            "phase": "before",
            "difficulty": 1,
            "explanation": "Loose objects become dangerous projectiles in strong winds.",
        },
        {
            "text": "During a storm, why should you avoid candles if the power goes out?",
            "options": {"A": "They smell bad", "B": "They are expensive", "C": "They pose a fire risk", "D": "They do not work"},
            "answer": "C",
            "phase": "during",
            "difficulty": 1,
            "explanation": "Candles can start fires, especially in storm conditions with wind and debris. Use torches instead.",
        },
        {
            "text": "Where should you take shelter during a severe storm?",
            "options": {"A": "Near large windows", "B": "On the roof", "C": "In an interior room on the lowest floor", "D": "In the garden"},
            "answer": "C",
            "phase": "during",
            "difficulty": 2,
            "explanation": "Interior rooms on the lowest floor offer the most protection from wind and flying debris.",
        },
        {
            "text": "After a storm, you encounter a downed power line. What should you do?",
            "options": {"A": "Move it with a stick", "B": "Step over it carefully", "C": "Assume it is live and report it to TNB", "D": "Splash water on it"},
            "answer": "C",
            "phase": "after",
            "difficulty": 1,
            "explanation": "Always assume downed power lines are live. Stay far away and report to TNB (1300-88-5454).",
        },
        {
            "text": "Which task helps prevent secondary flooding after a storm?",
            "options": {"A": "Closing all windows", "B": "Clearing debris from drains", "C": "Turning off WiFi", "D": "Checking social media"},
            "answer": "B",
            "phase": "after",
            "difficulty": 2,
            "explanation": "Blocked drains cause water to pool and flood. Clearing debris helps water drain properly.",
        },
        {
            "text": "Why should you unplug electrical appliances during a storm?",
            "options": {"A": "To save energy", "B": "To prevent damage from power surges", "C": "They might make noise", "D": "The wifi is down anyway"},
            "answer": "B",
            "phase": "during",
            "difficulty": 2,
            "explanation": "Lightning and power fluctuations during storms can cause damaging surges through connected appliances.",
        },
    ],

    # ── TSUNAMI ──────────────────────────────────────────────────────────
    "tsunami": [
        {
            "text": "What is a natural warning sign of a possible tsunami?",
            "options": {"A": "Cloudy skies", "B": "Sudden withdrawal of sea water from the shore", "C": "Heavy rain", "D": "Thunder"},
            "answer": "B",
            "phase": "before",
            "difficulty": 1,
            "explanation": "A sudden, unusual retreat of the ocean from the shore is one of the clearest natural tsunami warnings.",
        },
        {
            "text": "During a tsunami warning, where should you move?",
            "options": {"A": "To the beach to watch", "B": "High ground at least 30 metres elevation or 2 km inland", "C": "To the basement", "D": "Into a boat"},
            "answer": "B",
            "phase": "during",
            "difficulty": 1,
            "explanation": "High ground (≥30 m elevation) or at least 2 km inland provides safety from tsunami waves.",
        },
        {
            "text": "After the first tsunami wave, is it safe to return to the coast?",
            "options": {"A": "Yes, the danger is over", "B": "Yes, after 10 minutes", "C": "No — more waves may follow for hours", "D": "Only if the sun is out"},
            "answer": "C",
            "phase": "during",
            "difficulty": 2,
            "explanation": "Tsunami waves come in series. Later waves can be larger than the first and continue for hours.",
        },
        {
            "text": "If you feel a strong earthquake while near the coast, what should you do WITHOUT waiting for official warnings?",
            "options": {"A": "Continue your activity", "B": "Move immediately to high ground", "C": "Check your phone first", "D": "Go to the beach"},
            "answer": "B",
            "phase": "during",
            "difficulty": 2,
            "explanation": "A strong coastal earthquake may trigger a tsunami within minutes — move to high ground without waiting.",
        },
        {
            "text": "What is the recommended distance from shore for a tsunami go-bag to be useful?",
            "options": {"A": "5 km", "B": "Within 1 km of the coast", "C": "10 km", "D": "Anywhere"},
            "answer": "B",
            "phase": "before",
            "difficulty": 3,
            "explanation": "If you live within 1 km of the coast, having an always-ready go-bag is critical for rapid evacuation.",
        },
        {
            "text": "After a tsunami, why should you avoid the floodwater?",
            "options": {"A": "It is cold", "B": "It may contain debris, fuel, and sewage", "C": "It is salty", "D": "It is shallow"},
            "answer": "B",
            "phase": "after",
            "difficulty": 1,
            "explanation": "Tsunami floodwater carries dangerous debris, fuel, sewage, and structural wreckage.",
        },
    ],

    # ── HAZE ─────────────────────────────────────────────────────────────
    "haze": [
        {
            "text": "Which type of mask is effective against haze particles?",
            "options": {"A": "Surgical mask", "B": "N95 mask", "C": "Cloth mask", "D": "No mask needed"},
            "answer": "B",
            "phase": "during",
            "difficulty": 1,
            "explanation": "N95 masks filter at least 95% of airborne particles. Surgical and cloth masks are not effective against haze.",
        },
        {
            "text": "At what API (Air Pollution Index) level should you stay indoors?",
            "options": {"A": "50", "B": "100", "C": "Above 200", "D": "300 only"},
            "answer": "C",
            "phase": "during",
            "difficulty": 1,
            "explanation": "API above 200 is classified as 'Very Unhealthy'. Outdoor exposure should be minimised.",
        },
        {
            "text": "What type of air purifier filter is recommended for haze?",
            "options": {"A": "Carbon filter only", "B": "HEPA filter", "C": "UV filter", "D": "No filter needed"},
            "answer": "B",
            "phase": "before",
            "difficulty": 2,
            "explanation": "HEPA (High-Efficiency Particulate Air) filters capture 99.97% of particles ≥0.3 microns.",
        },
        {
            "text": "Which government body provides official API readings in Malaysia?",
            "options": {"A": "JAKIM", "B": "DOE (Department of Environment)", "C": "EPF", "D": "Bank Negara"},
            "answer": "B",
            "phase": "before",
            "difficulty": 2,
            "explanation": "The Department of Environment (DOE) Malaysia monitors and publishes Air Pollution Index readings.",
        },
        {
            "text": "After haze clears and API drops below 50, a good practice is to:",
            "options": {"A": "Keep windows closed permanently", "B": "Ventilate your home by opening windows", "C": "Dispose of the air purifier", "D": "Continue wearing N95 outdoors"},
            "answer": "B",
            "phase": "after",
            "difficulty": 1,
            "explanation": "Once API is low, ventilating clears trapped indoor particles and freshens the air.",
        },
        {
            "text": "Why should vigorous outdoor exercise be avoided during haze?",
            "options": {"A": "It is too hot", "B": "Increased breathing rate draws more particles deep into the lungs", "C": "Visibility is poor", "D": "It is not fun"},
            "answer": "B",
            "phase": "during",
            "difficulty": 3,
            "explanation": "Exercise increases breathing rate and depth, pulling fine particles deeper into the respiratory system.",
        },
    ],
}


class AdaptiveQuizEngine:
    """
    AI-driven adaptive quiz engine.

    Selection algorithm:
    1. Weight each phase (before/during/after) inversely to the user's
       historical accuracy on that phase.  Phases with lower scores get
       heavier weight → more questions from weak areas.
    2. Select difficulty based on overall mastery:
       - mastery < 40 %  → mostly easy  (difficulty 1)
       - 40 – 70 %       → mixed        (difficulty 1-2)
       - > 70 %          → harder       (difficulty 2-3)
    3. Sample questions using the phase weights as a probability
       distribution, avoiding recently-asked questions when possible.
    """

    @staticmethod
    def generate_quiz(
        hazard_type: str,
        num_questions: int = 5,
        phase_scores: Optional[Dict[str, float]] = None,
        overall_mastery: float = 0.0,
    ) -> List[Dict]:
        """
        Generate a personalised quiz.

        Args:
            hazard_type: e.g. 'flood', 'landslide'
            num_questions: number of questions to return
            phase_scores: dict of {phase: accuracy_0_to_1} from history
            overall_mastery: 0-1 overall score across all attempts

        Returns:
            List of question dicts (without 'answer' and 'explanation'
            stripped out — those are held server-side for grading).
        """
        bank = QUESTION_BANK.get(hazard_type, QUESTION_BANK.get("flood", []))
        if not bank:
            return []

        # Determine target difficulty range
        if overall_mastery < 0.4:
            allowed_diff = {1, 2}
            prefer_diff = 1
        elif overall_mastery < 0.7:
            allowed_diff = {1, 2, 3}
            prefer_diff = 2
        else:
            allowed_diff = {2, 3}
            prefer_diff = 3

        # Filter by allowed difficulty
        pool = [q for q in bank if q["difficulty"] in allowed_diff]
        if len(pool) < num_questions:
            pool = list(bank)  # fallback to full bank

        # Compute phase weights (inverse of accuracy → weak areas weighted more)
        phases = ["before", "during", "after"]
        if phase_scores:
            raw = []
            for p in phases:
                acc = phase_scores.get(p, 0.5)
                raw.append(1.0 - acc + 0.1)  # +0.1 floor so no phase gets zero
            weights = np.array(raw, dtype=np.float64)
        else:
            weights = np.ones(len(phases), dtype=np.float64)

        weights /= weights.sum()
        phase_weight_map = dict(zip(phases, weights.tolist()))

        # Assign selection probability to each question
        q_weights = []
        for q in pool:
            pw = phase_weight_map.get(q["phase"], 0.33)
            # Bonus for matching preferred difficulty
            diff_bonus = 1.5 if q["difficulty"] == prefer_diff else 1.0
            q_weights.append(pw * diff_bonus)

        q_weights_arr = np.array(q_weights, dtype=np.float64)
        q_weights_arr /= q_weights_arr.sum()

        n = min(num_questions, len(pool))
        indices = np.random.choice(len(pool), size=n, replace=False, p=q_weights_arr)

        selected = [pool[int(i)] for i in indices]

        # Return questions without answers (for client)
        client_questions = []
        for idx, q in enumerate(selected):
            client_questions.append({
                "index": idx,
                "text": q["text"],
                "options": q["options"],
                "phase": q["phase"],
                "difficulty": q["difficulty"],
            })

        return client_questions

    @staticmethod
    def grade_quiz(
        hazard_type: str,
        answers: List[Dict],
    ) -> Dict:
        """
        Grade submitted answers and return detailed results.

        Args:
            answers: list of {"index": int, "question_text": str, "selected": "A"|"B"|"C"|"D"}

        Returns:
            {
                "score": int,
                "total": int,
                "percentage": float,
                "phase_scores": {phase: accuracy},
                "results": [{question, selected, correct, is_correct, explanation}],
                "weak_areas": [phase names with < 60% accuracy],
                "recommendations": [str],
            }
        """
        bank = QUESTION_BANK.get(hazard_type, QUESTION_BANK.get("flood", []))
        # Build lookup by question text
        lookup = {q["text"]: q for q in bank}

        results = []
        phase_correct: Dict[str, int] = {}
        phase_total: Dict[str, int] = {}

        for ans in answers:
            q_text = ans.get("question_text", "")
            selected = ans.get("selected", "")
            q = lookup.get(q_text)
            if not q:
                continue

            is_correct = selected == q["answer"]
            phase = q["phase"]
            phase_total[phase] = phase_total.get(phase, 0) + 1
            if is_correct:
                phase_correct[phase] = phase_correct.get(phase, 0) + 1

            results.append({
                "question": q_text,
                "selected": selected,
                "correct": q["answer"],
                "is_correct": is_correct,
                "explanation": q["explanation"],
                "phase": phase,
            })

        total = len(results)
        correct = sum(1 for r in results if r["is_correct"])
        percentage = (correct / total * 100) if total > 0 else 0

        # Phase-level accuracy
        phase_scores = {}
        for p in ["before", "during", "after"]:
            t = phase_total.get(p, 0)
            c = phase_correct.get(p, 0)
            phase_scores[p] = (c / t) if t > 0 else None

        # Identify weak areas
        weak = [p for p, s in phase_scores.items() if s is not None and s < 0.6]

        # AI-generated recommendations
        recs = AdaptiveQuizEngine._build_recommendations(
            hazard_type, phase_scores, percentage, weak
        )

        return {
            "score": correct,
            "total": total,
            "percentage": round(percentage, 1),
            "phase_scores": phase_scores,
            "results": results,
            "weak_areas": weak,
            "recommendations": recs,
        }

    @staticmethod
    def _build_recommendations(
        hazard_type: str,
        phase_scores: Dict[str, Optional[float]],
        overall_pct: float,
        weak_areas: List[str],
    ) -> List[str]:
        """Generate personalised study recommendations based on performance."""
        recs = []
        ht = hazard_type.replace("_", " ").title()

        if overall_pct >= 80:
            recs.append(
                f"Excellent! You have strong {ht} knowledge. "
                f"Try the quiz again at a harder difficulty to challenge yourself."
            )
        elif overall_pct >= 60:
            recs.append(
                f"Good progress on {ht} preparedness! "
                f"Review the areas below to strengthen your knowledge."
            )
        else:
            recs.append(
                f"Your {ht} knowledge needs improvement. "
                f"We recommend re-reading the learning modules before retaking the quiz."
            )

        phase_labels = {
            "before": "Before — Preparedness & Planning",
            "during": "During — Immediate Response",
            "after": "After — Recovery & Follow-up",
        }

        for area in weak_areas:
            label = phase_labels.get(area, area)
            recs.append(f"Focus on: {label} — revisit the '{area.title()}' tab in the learning module.")

        if not weak_areas and overall_pct < 100:
            recs.append("Tip: Retake the quiz periodically to reinforce your knowledge.")

        return recs

    @staticmethod
    def compute_mastery(attempts: List[Dict]) -> Dict:
        """
        Compute overall mastery and per-phase scores from historical attempts.

        Args:
            attempts: list of {"score": int, "total": int, "phase_scores": {}}

        Returns:
            {"overall_mastery": float, "phase_scores": {phase: float}, "total_attempts": int}
        """
        if not attempts:
            return {"overall_mastery": 0.0, "phase_scores": {}, "total_attempts": 0}

        # Weighted average — recent attempts count more (exponential decay)
        n = len(attempts)
        decay = np.array([0.7 ** (n - 1 - i) for i in range(n)], dtype=np.float64)
        decay /= decay.sum()

        scores = np.array(
            [a["score"] / a["total"] if a["total"] > 0 else 0 for a in attempts],
            dtype=np.float64,
        )
        overall = float(np.dot(decay, scores))

        # Phase scores — average across all attempts that have them
        phase_data: Dict[str, List[float]] = {}
        for a in attempts:
            ps = a.get("phase_scores", {})
            for p, v in ps.items():
                if v is not None:
                    phase_data.setdefault(p, []).append(v)

        phase_scores = {
            p: round(float(np.mean(vals)), 3) for p, vals in phase_data.items()
        }

        return {
            "overall_mastery": round(overall, 3),
            "phase_scores": phase_scores,
            "total_attempts": n,
        }
