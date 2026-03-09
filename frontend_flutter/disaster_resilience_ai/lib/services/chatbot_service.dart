/// Rule-based disaster knowledge chatbot.
/// Matches user messages to topics and returns detailed, helpful responses.
class ChatbotService {
  static const List<_Rule> _rules = [
    // ── Greetings ──────────────────────────────────────────────────────────
    _Rule(
      keywords: ['hello', 'hi', 'hey', 'salam', 'aloha', 'helo'],
      response:
          'Hello! 👋 I\'m your Disaster Resilience AI assistant.\n\nI can help you with:\n• Flood safety & response\n• Earthquake preparedness\n• Landslide warnings\n• Evacuation procedures\n• Emergency kit guidance\n• First aid tips\n• How to report incidents\n\nWhat would you like to know?',
    ),

    // ── Flood ──────────────────────────────────────────────────────────────
    _Rule(
      keywords: [
        'flood',
        'banjir',
        'flooding',
        'water rising',
        'flashflood',
        'flash flood',
      ],
      response:
          '🌊 **Flood Safety Guide**\n\n**Before a Flood:**\n• Move valuables and important documents to upper floors\n• Prepare an emergency kit (water, food, medicine, torch)\n• Know your nearest evacuation centre\n• Fill sandbags if time permits\n\n**During a Flood:**\n• Never walk or drive through floodwater — 6 inches can knock you down\n• Turn off electricity at the main breaker if water rises inside\n• Move to higher ground immediately if ordered to evacuate\n• Call 999 (Emergency) or 991 (Fire & Rescue) if trapped\n\n**After a Flood:**\n• Do not return home until authorities declare it safe\n• Wear rubber boots — floodwater carries disease\n• Document all damage for insurance claims\n• Boil water before drinking',
    ),

    // ── Evacuate / Evacuation ──────────────────────────────────────────────
    _Rule(
      keywords: [
        'evacuate',
        'evacuation',
        'escape',
        'flee',
        'leave',
        'pusat pemindahan',
        'relief centre',
      ],
      response:
          '🏃 **Evacuation Guide**\n\n**When to Evacuate:**\n• When authorities issue an evacuation order — don\'t hesitate\n• If water is rising rapidly around your home\n• If you smell gas or see structural damage\n\n**How to Evacuate:**\n1. Grab your emergency kit\n2. Turn off gas, electricity & water\n3. Lock your home\n4. Use designated evacuation routes (check the Safe Routes tab in the app)\n5. Do NOT use flooded roads\n\n**Relief / Evacuation Centres:**\n• Schools and community halls are typically used\n• You can check the Map tab for nearby centres\n• Bring ID documents, medicine, and baby supplies if needed\n\n**Emergency Numbers:**\n• 999 — Police / Ambulance\n• 994 — Fire & Rescue\n• 991 — Bomba (Fire Dept)',
    ),

    // ── Earthquake ────────────────────────────────────────────────────────
    _Rule(
      keywords: [
        'earthquake',
        'gempa',
        'tremor',
        'seismic',
        'quake',
        'ground shaking',
      ],
      response:
          '🏚 **Earthquake Safety Guide**\n\n**During an Earthquake (DROP, COVER, HOLD ON):**\n• DROP to your hands and knees\n• Take COVER under a sturdy desk or table — protect your head\n• HOLD ON until shaking stops\n• Stay away from windows, heavy furniture, and exterior walls\n• If outdoors, move away from buildings and power lines\n\n**After the Shaking Stops:**\n• Expect aftershocks — stay alert\n• Check for gas leaks (smell or hissing) — if detected, open windows and leave\n• Do not use elevators\n• Check yourself and others for injuries\n• Inspect building for damage before entering\n\n**In Malaysia:**\n• West Malaysia has low seismic risk\n• Sabah (especially near Ranau) has moderate risk\n• If in a high-rise, practise regular evacuation drills',
    ),

    // ── Landslide ─────────────────────────────────────────────────────────
    _Rule(
      keywords: [
        'landslide',
        'tanah runtuh',
        'mudslide',
        'slope',
        'rocky',
        'debris flow',
      ],
      response:
          '⛰ **Landslide Safety Guide**\n\n**Warning Signs:**\n• Cracks in walls or ground\n• Doors or windows that suddenly jam\n• Unusual sounds (cracking trees, rumbling)\n• Spring water appearing in new spots\n• Tilting trees or utility poles\n\n**During a Landslide:**\n• Move quickly away from the path of debris\n• Run to the side — not straight ahead or behind\n• If escape is impossible, curl into a tight ball and protect your head\n\n**High-Risk Areas in Malaysia:**\n• Highland areas in Pahang, Cameron Highlands, Genting\n• Slopes near construction sites\n• Road cuts and embankments after heavy rain\n\n**Prevention:**\n• Avoid building near steep slopes\n• Ensure proper drainage around your home\n• Report cracked retaining walls to your local council (JPS)',
    ),

    // ── Typhoon / Storm / Strong Wind ─────────────────────────────────────
    _Rule(
      keywords: [
        'typhoon',
        'storm',
        'hurricane',
        'cyclone',
        'strong wind',
        'monsoon',
        'ribut',
        'angin kencang',
      ],
      response:
          '🌀 **Severe Storm Safety Guide**\n\n**Before a Storm:**\n• Trim overhanging tree branches near your home\n• Secure or bring in outdoor furniture\n• Stock up on food, water (at least 3 days), torches and batteries\n• Charge all devices and power banks\n\n**During a Storm:**\n• Stay indoors away from windows\n• Avoid using wired telephones during lightning\n• Avoid showering during thunderstorms (lightning can travel through plumbing)\n• Do not go outdoors until the storm has fully passed\n\n**After a Storm:**\n• Watch out for downed power lines — assume they are live\n• Avoid flooded roads\n• Report hazardous trees or lines to TNB (1300-88-5454)',
    ),

    // ── Emergency Kit / Bag ───────────────────────────────────────────────
    _Rule(
      keywords: [
        'kit',
        'bag',
        'emergency bag',
        'go bag',
        'supply',
        'prepare',
        'preparednes',
        'beg kecemasan',
      ],
      response:
          '🎒 **Emergency Kit Checklist**\n\n**Water & Food (min. 3 days):**\n• 3 litres of water per person per day\n• Non-perishable food (canned goods, biscuits, energy bars)\n\n**Documents (in waterproof bag):**\n• IC / Passport copies\n• Bank card / some cash\n• Insurance documents\n• Medical records / prescriptions\n\n**Health & Safety:**\n• First aid kit\n• Prescribed medications (7-day supply)\n• Hand sanitiser & masks\n• Whistle (to signal for help)\n\n**Tools & Communication:**\n• Torch with extra batteries\n• Battery / hand-crank radio\n• Fully-charged power bank\n• Multi-tool or pocket knife\n\n**Comfort:**\n• Warm clothing and rain jacket\n• Blanket\n• Baby/pet supplies if applicable\n\nStore your kit somewhere easily accessible and review it every 6 months.',
    ),

    // ── First Aid ─────────────────────────────────────────────────────────
    _Rule(
      keywords: [
        'first aid',
        'injury',
        'wound',
        'bleeding',
        'cpr',
        'choking',
        'pertolongan cemas',
      ],
      response:
          '🩺 **Emergency First Aid Tips**\n\n**Bleeding:**\n• Apply firm, direct pressure with a clean cloth\n• Elevate the limb if possible\n• Do not remove the cloth — add more if it soaks through\n\n**CPR (Adult):**\n1. Check for responsiveness\n2. Call 999 immediately\n3. 30 chest compressions (hard & fast, 5 cm deep)\n4. 2 rescue breaths\n5. Repeat until ambulance arrives\n\n**Choking:**\n• Encourage them to cough\n• Give 5 firm back blows between shoulder blades\n• 5 abdominal thrusts (Heimlich manoeuvre)\n• Repeat until object is dislodged or they lose consciousness\n\n**Heat Exhaustion:**\n• Move to a cool, shaded area\n• Give small sips of cool water\n• Apply cool wet cloths to neck and armpits\n\n⚠️ Always call 999 in a genuine medical emergency.',
    ),

    // ── Report an Incident ────────────────────────────────────────────────
    _Rule(
      keywords: [
        'report',
        'submit',
        'laporkan',
        'incident',
        'hazard',
        'danger',
      ],
      response:
          '📋 **How to Report an Incident**\n\nYou can report hazards directly in this app:\n1. Tap the **Reports** tab (chart icon) at the bottom\n2. Tap **Submit Report**\n3. Describe  the hazard, location, and include a photo if possible\n4. Submit — your report goes to local authorities\n\n**Official Channels:**\n• JPS (Jabatan Pengairan & Saliran): 1800-88-8151\n• Bomba: 994\n• NADMA (National Disaster Management Agency): 03-8064 2400\n• MySejahtera app for health-related emergencies\n\n**Tips for Good Reports:**\n• Be specific about the location (GPS coordinates help)\n• Describe severity (e.g. water level, number of people affected)\n• Note the time of observation',
    ),

    // ── Emergency Contacts ────────────────────────────────────────────────
    _Rule(
      keywords: [
        'contact',
        'number',
        'call',
        'phone',
        'hotline',
        'emergency number',
        'nombor',
      ],
      response:
          '📞 **Malaysia Emergency Contacts**\n\n| Service | Number |\n|---------|--------|\n| Police / General Emergency | **999** |\n| Fire & Rescue (Bomba) | **994** |\n| Ambulance | **999** |\n| JPS (Floods & Drainage) | **1800-88-8151** |\n| NADMA (Disaster HQ) | **03-8064 2400** |\n| TNB (Power Failure) | **1300-88-5454** |\n| PLUS Highway | **1800-88-0000** |\n| Mental Health Hotline (Befrienders) | **03-7627 2929** |\n\nYou can also save these in the **Emergency Contacts** section of the app (Quick Actions on Home tab).',
    ),

    // ── Safe Routes ───────────────────────────────────────────────────────
    _Rule(
      keywords: [
        'route',
        'path',
        'way out',
        'direction',
        'navigate',
        'safe route',
        'escape route',
      ],
      response:
          '🗺 **Safe Evacuation Routes**\n\nThe app has a built-in **Safe Routes** feature:\n• Tap **Safe Routes** in the Quick Actions on the Home tab\n• It will display recommended evacuation paths for your area\n\n**General Rules:**\n• Always follow roads marked by authorities during disasters\n• Avoid low-lying roads and underpasses during floods\n• Tune to Radio Malaysia (RTM) for live road updates\n• Highway toll plazas will waive fees during declared disasters\n\n**Offline Tip:** Download Google Maps offline for your area in case mobile data is unavailable.',
    ),

    // ── Warning system ────────────────────────────────────────────────────
    _Rule(
      keywords: [
        'warning',
        'alert',
        'amaran',
        'advisory',
        'observe',
        'notification',
        'level',
      ],
      response:
          '🚨 **Understanding Warning Levels**\n\nThis app uses a 4-tier warning system:\n\n🔵 **Advisory** — Be aware. Monitor conditions. No immediate action required.\n\n🟡 **Observe** — Conditions are developing. Prepare your emergency kit. Stay informed.\n\n🟠 **Warning** — Significant risk. Secure your home. Be ready to evacuate on short notice.\n\n🔴 **Evacuate** — Leave now. Follow official evacuation orders. Do not delay.\n\nYou can view all active warnings on the **Home** dashboard or in the **Map** tab.',
    ),

    // ── Risk Map ──────────────────────────────────────────────────────────
    _Rule(
      keywords: [
        'risk',
        'map',
        'zone',
        'area',
        'danger zone',
        'peta',
        'kawasan',
      ],
      response:
          '🗺 **Risk Zones & Map**\n\nThe **Map** tab in the app shows:\n• Active hazard zones colour-coded by severity\n• Your current location relative to risk areas\n• Nearby evacuation centres\n\n**Colour Guide:**\n🟢 Green — Low risk\n🟡 Yellow — Moderate risk\n🟠 Orange — High risk\n🔴 Red — Critical / Evacuate\n\nTap any zone on the map for detailed information about the hazard type and recommended action.',
    ),

    // ── Weather ───────────────────────────────────────────────────────────
    _Rule(
      keywords: [
        'weather',
        'rain',
        'cuaca',
        'temperature',
        'forecast',
        'cloud',
        'humidity',
        'wind',
      ],
      response:
          '🌤 **Weather & Disaster Link**\n\nYou can check the current weather by tapping the **weather widget** in the top-right of the Home screen.\n\n**Weather & Disaster Connection:**\n• Heavy rain (>50 mm/hour) significantly increases flood risk\n• Continuous rain for 3+ days saturates soil and raises landslide risk\n• Strong winds above 60 km/h can cause structural damage\n\n**Malaysian Monsoons:**\n• **Northeast Monsoon** (Nov–Mar): Affects east coast states — Kelantan, Terengganu, Pahang. High flood risk.\n• **Southwest Monsoon** (May–Sep): Generally drier, but occasional heavy showers.\n\nAlways check weather forecasts before travelling during monsoon season.',
    ),

    // ── School / Children ─────────────────────────────────────────────────
    _Rule(
      keywords: [
        'school',
        'sekolah',
        'children',
        'kids',
        'student',
        'child',
        'parent',
      ],
      response:
          '🏫 **School & Children Safety**\n\n**School Preparedness:**\n• The app has a **School Registry** under Quick Actions\n• Schools register their emergency contacts and preparedness level\n• Parents can verify their school\'s preparedness status\n\n**Teaching Children:**\n• Teach them to call 999 and relay their address\n• Practice the DROP, COVER, HOLD ON drill regularly\n• Establish a family meeting point outside the home\n• Children should carry a card with emergency contact numbers\n\n**During School Hours if Disaster Strikes:**\n• Schools follow Civil Defence (APM) protocols\n• Parents are notified via the school\'s notification system\n• Do not rush to school — it may block emergency vehicles',
    ),

    // ── What app can do ───────────────────────────────────────────────────
    _Rule(
      keywords: [
        'app',
        'feature',
        'function',
        'dapat',
        'boleh',
        'do you',
        'what can',
      ],
      response:
          '📱 **What This App Can Do**\n\n• 🔔 **Real-time Warnings** — Live alerts based on your location\n• 🗺 **Risk Map** — Visualise hazard zones in your area\n• 📋 **Community Reports** — Submit and view local incident reports\n• 🏫 **School Registry** — Check school disaster preparedness\n• 🏃 **Safe Routes** — Recommended evacuation paths\n• 📞 **Emergency Contacts** — Quick access to hotlines\n• 🌤 **Weather** — Live weather + 7-day forecast\n• 🤖 **This chatbot** — Ask anything about disaster preparedness!\n\nAll features work together to keep you and your community safer.',
    ),

    // ── Thanks ────────────────────────────────────────────────────────────
    _Rule(
      keywords: [
        'thank',
        'thanks',
        'terima kasih',
        'ok',
        'good',
        'great',
        'awesome',
        'helpful',
      ],
      response:
          'You\'re welcome! 😊 Stay safe and prepared. Remember:\n\n• Always have an emergency kit ready\n• Know your nearest evacuation centre\n• Keep emergency numbers saved in your phone\n\nFeel free to ask me anything else about disaster safety! 🛡️',
    ),
  ];

  /// Returns the best matching response for [message], or a default fallback.
  String getResponse(String message) {
    final lower = message.toLowerCase().trim();

    for (final rule in _rules) {
      for (final keyword in rule.keywords) {
        if (lower.contains(keyword)) {
          return rule.response;
        }
      }
    }

    // Fallback — suggest topics
    return '🤔 I didn\'t quite catch that. Here are some topics I can help with:\n\n• **Flood** safety tips\n• **Earthquake** preparedness\n• **Landslide** warnings\n• **Evacuation** procedures\n• **Emergency kit** checklist\n• **First aid** basics\n• **Emergency contacts**\n• **Report** an incident\n• **Weather** & disaster link\n• **App features**\n\nTry asking something like "What should I do during a flood?" 💬';
  }

  /// Returns suggested starter questions for the chat opening screen.
  static const List<String> suggestions = [
    'What should I do during a flood?',
    'How do I build an emergency kit?',
    'What are the warning levels?',
    'Emergency contact numbers',
    'Earthquake safety tips',
    'How do I evacuate safely?',
  ];
}

class _Rule {
  final List<String> keywords;
  final String response;
  const _Rule({required this.keywords, required this.response});
}
