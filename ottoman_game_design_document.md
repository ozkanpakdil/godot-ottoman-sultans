# Game Design Document & Development Prompt: Ottoman Dynastic Timeline Game

This document serves as the complete technical architecture, historical blueprint, and step-by-step implementation guide for building **"Chronicles of the House of Osman"** using the Godot Engine. 

---

## 1. Executive Summary & Vision

### Game Overview
An educational, minimalist narrative-adventure and interactive timeline covering the 600+ year history of the Ottoman Empire (1299–1922). The primary objective is educational retention rather than mechanical mastery. The player navigates chronologically through the reigns of the Sultans, exploring major historical events, military campaigns, marital alliances, and structural reforms.

### Core Pillars
*   **Education First:** Minimalist mechanics that reduce cognitive overload and focus entirely on storytelling and historical accuracy.
*   **High Retention, Low Friction:** Chapter tests are designed to reinforce knowledge, not penalize the user. 
*   **Multimedia Integration:** Curation of historical discussions (e.g., Prof. Dr. İlber Ortaylı, Murat Bardakçı) embedded directly into the narrative transitions.
*   **Passive Progression:** Time spent actively reading and learning is tracked, rewarded, and converted into an official leaderboard score.

---

## 2. Technical Architecture (Godot Engine)

### Project Configuration
*   **Engine Version:** Godot 4.x (Stable)
*   **Render Method:** `gl_compatibility` (Best for maximizing mobile battery life and legacy device support).
*   **Display Settings:** Portrait orientation (`Window/Handheld/Orientation: portrait`), Canvas Items stretch mode (`Window/Stretch/Mode: canvas_items`), Aspect: `expand`. Images of sultans can come from wiki.

### File Structure Layout
```text
res://
├── assets/
│   ├── fonts/          # Elegant serif fonts (e.g., Cinzel, Playfair Display)
│   ├── UI/             # Minimalist custom buttons, frames, icons
│   └── videos/         # Placeholder thumbnails for video integrations
├── core/
│   ├── Autoload/
│   │   ├── GameManager.gd   # Tracks time, current chapter, scores
│   │   └── SaveManager.gd   # Handles JSON serialization for game state
│   └── Systems/
│       ├── QuizSystem.gd
│       └── TimeTracker.gd
├── data/
│   └── historical_db.json   # Full database of Sultans, battles, wives, and video URLs
└── scenes/
    ├── MainMenu/
    ├── Timeline/
    ├── Quiz/
    └── Leaderboard/
```

### Core Data Structure (`historical_db.json`)
```json
{
  "chapters": [
    {
      "id": 1,
      "title": "The Foundation (1299–1451)",
      "sultans": [
        {
          "name": "Osman I (Gazi)",
          "reign": "1299–1326",
          "wives": ["Malhun Hatun", "Rabia Bala Hatun"],
          "battles": [
            {"name": "Battle of Bapheus (1302)", "description": "First major clash against the Byzantine Empire."}
          ],
          "video_url": "https://www.youtube.com/watch?v=example_ilber_osman",
          "summary": "Founder of the dream that became an empire..."
        }
      ]
    }
  ]
}
```

---

## 3. Core Systems Source Code

### `GameManager.gd` (Autoload)
```gdscript
extends Node

var current_chapter_index: int = 0
var current_sultan_index: int = 0
var total_study_time: float = 0.0
var score: int = 0
var completed_quizzes: Dictionary = {}

func _process(delta: float) -> void:
    # Continuously track learning time in seconds
    total_study_time += delta

func calculate_score(quiz_points: int) -> void:
    # 1 point per 10 seconds learned + quiz rewards
    var time_points = int(total_study_time / 10.0)
    score = time_points + quiz_points
    update_game_center()

func update_game_center() -> void:
    # Interface with Godot iOS GameCenter / Android Play Games plugin
    if Engine.has_singleton("GameCenter"):
        var gc = Engine.get_singleton("GameCenter")
        gc.submit_score({
            "score": score,
            "leaderboard_id": "com.ottoman.timeline.highscore"
        })
```

### `SaveManager.gd` (Autoload)
```gdscript
extends Node

const SAVE_PATH = "user://ottoman_save.dat"
const ENCRYPTION_KEY = "SultanSecretKey1299!"

func save_progress() -> void:
    var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
    if file:
        var data = {
            "current_chapter_index": GameManager.current_chapter_index,
            "current_sultan_index": GameManager.current_sultan_index,
            "total_study_time": GameManager.total_study_time,
            "score": GameManager.score,
            "completed_quizzes": GameManager.completed_quizzes
        }
        file.store_var(data)
        file.close()

func load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, ENCRYPTION_KEY)
    if file:
        var data = file.get_var()
        GameManager.current_chapter_index = data.get("current_chapter_index", 0)
        GameManager.current_sultan_index = data.get("current_sultan_index", 0)
        GameManager.total_study_time = data.get("total_study_time", 0.0)
        GameManager.score = data.get("score", 0)
        GameManager.completed_quizzes = data.get("completed_quizzes", {})
        file.close()
```

---

## 4. The 500-Year Historical Roadmap (Chapters & Data)

### Chapter 1: The Establishment & Foundation Era (1299–1451)
*   **Osman I (1299–1326)**
    *   *Spouses:* Malhun Hatun, Rabia Bala Hatun.
    *   *Key Battles:* Battle of Bapheus (1302), Siege of Prusa (Bursa).
    *   *Video Integration:* İlber Ortaylı - Kuruluş Dönemi ve Osman Gazi.
*   **Orhan Gazi (1326–1362)**
    *   *Spouses:* Nilüfer Hatun, Asporça Hatun, Theodora Hatun.
    *   *Key Battles:* Battle of Pelekanon (1329), Conquest of Nicaea (İznik).
*   **Murad I (1362–1389)**
    *   *Spouses:* Gülçiçek Hatun, Marya Hatun.
    *   *Key Battles:* Battle of Maritsa (1371), First Battle of Kosovo (1389) – *Martyred on the field*.
*   **Bayezid I (Yıldırım) (1389–1402)**
    *   *Spouses:* Devlet Hatun, Despina Hatun.
    *   *Key Battles:* Battle of Nicopolis (1396), Battle of Ankara (1402) – *Captured by Tamerlane*.
*   **Interregnum (Fetret Devri) & Mehmed I (1413–1421)**
    *   *Spouses:* Emine Hatun.
    *   *Key Triumphs:* Restoration of centralized authority post-civil war.
*   **Murad II (1421–1444, 1446–1451)**
    *   *Spouses:* Hüma Hatun, Mara Hatun.
    *   *Key Battles:* Crusade of Varna (1444), Second Battle of Kosovo (1448).

### Chapter 2: The Age of Expansion & Zenith (1451–1566)
*   **Mehmed II (Fatih the Conqueror) (1451–1481)**
    *   *Spouses:* Gülbahar Hatun, Çiçek Hatun, Sittişah Hatun.
    *   *Key Battles:* Fall of Constantinople (1453), Siege of Belgrade (1456), Conquest of Trebizond (1461).
    *   *Video Integration:* Murat Bardakçı & İlber Ortaylı - İstanbul'un Fethi ve Fatih.
*   **Bayezid II (1481–1512)**
    *   *Spouses:* Gülbahar Hatun, Ayşe Hatun.
    *   *Key Events:* Rebellion of Cem Sultan, Rescue of Iberian Jews (1492).
*   **Selim I (Yavuz the Grim) (1512–1520)**
    *   *Spouses:* Ayşe Hafsa Sultan.
    *   *Key Battles:* Battle of Chaldiran (1514), Battle of Marj Dabiq (1516), Battle of Ridaniya (1517) – *Transfer of the Caliphate*.
*   **Suleiman I (The Magnificent / Kanuni) (1520–1566)**
    *   *Spouses:* Hürrem Sultan (Legal Wife), Mahidevran Hatun.
    *   *Key Battles:* Siege of Belgrade (1521), Battle of Mohács (1526), First Siege of Vienna (1529), Siege of Szigetvár (1566).
    *   *Video Integration:* İlber Ortaylı - Muhteşem Süleyman Devri.

### Chapter 3: Stagnation & Internal Transformations (1566–1683)
*   **Selim II (1566–1574)**
    *   *Spouses:* Nurbanu Sultan.
    *   *Key Battles:* Conquest of Cyprus (1571), Battle of Lepanto (1571).
*   **Murad III (1574–1595)**
    *   *Spouses:* Safiye Sultan.
    *   *Key Events:* Peak of the Sultanate of Women, Ottoman–Safavid War (1578–1590).
*   **Mehmed III (1595–1603)**
    *   *Spouses:* Handan Sultan, Halime Sultan.
    *   *Key Battles:* Battle of Keresztes (1596).
*   **Ahmed I (1603–1617)**
    *   *Spouses:* Kösem Sultan, Mahfiruz Hatun.
    *   *Key System Changes:* Abolition of fratricide, introduction of the *Ekberiyet* (seniority) system. Construction of the Blue Mosque.
*   **Mustafa I (1617–1618, 1622–1623) & Osman II (Genç Osman) (1618–1622)**
    *   *Key Events:* Janissary revolt, deposition and tragic assassination of Genç Osman.
*   **Murad IV (1623–1640)**
    *   *Spouses:* Ayşe Sultan.
    *   *Key Battles:* Recapture of Baghdad (1638), absolute internal stabilization campaigns.
*   **Ibrahim (1640–1648) & Mehmed IV (Avcı) (1648–1687)**
    *   *Spouses:* Turhan Hatun, Gülnuş Sultan.
    *   *Key Battles:* Siege of Candia (Crete), Second Siege of Vienna (1683).

### Chapter 4: The Decline, Wars of Survival & Reform (1683–1839)
*   **Suleiman II, Ahmed II, Mustafa II (1687–1703)**
    *   *Key Battles:* Battle of Zenta (1697), Treaty of Karlowitz (1699) – *First major loss of territory*.
*   **Ahmed III (1703–1730)**
    *   *Spouses:* Emetullah Kadın.
    *   *Key Era:* The Tulip Period (Lale Devri), introduction of the printing press (İbrahim Müteferrika). Patrona Halil Rebellion.
*   **Mahmud I, Osman III, Mustafa III, Abdulhamid I (1730–1789)**
    *   *Key Battles:* Treaty of Belgrade (1739), Battle of Chesma (1770), Treaty of Küçük Kaynarca (1774).
*   **Selim III (1789–1707)**
    *   *Key Reform:* Creation of the modernized *Nizam-ı Cedid* army. Deposed by Kabakçı Mustafa revolt.
*   **Mahmud II (1808–1839)**
    *   *Spouses:* Bezmiâlem Sultan, Pertevniyal Sultan.
    *   *Key Events:* Destruction of the Janissary Corps (The Auspicious Incident / Vaka-i Hayriye, 1826).

### Chapter 5: The Late Modern Era & Dissolution (1839–1922)
*   **Abdulmejid I (1839–1861)**
    *   *Key Reforms:* Tanzimat Edict (1839), Edict of Reform (1856), Crimean War (1853–1856).
*   **Abdulaziz (1861–1876)**
    *   *Key Events:* First European royal tours, massive naval expansions.
*   **Murad V (1876)**
    *   *Key Events:* Shortest reign (93 days) due to mental health crisis.
*   **Abdulhamid II (1876–1909)**
    *   *Spouses:* Bedrifelek Kadın, Bidar Kadın.
    *   *Key Events:* First Constitutional Era (Kanun-ı Esasi), Russo-Turkish War (1877–1878), Hijaz Railway construction, 1908 Young Turk Revolution.
    *   *Video Integration:* Murat Bardakçı - Sultan Abdülhamid Dönemi Gerçekleri.
*   **Mehmed V Reşad (1909–1918)**
    *   *Key Battles:* Italo-Turkish War, Balkan Wars, World War I (Gallipoli Campaign, Siege of Kut Al Amara).
*   **Mehmed VI Vahdeddin (1918–1922)**
    *   *Key Events:* Occupation of Istanbul, Abolition of the Sultanate (1922).

---

## 5. Gamification, Quizzes & UX Design

### Minimalist Retention Mechanics
1.  **Passive Chronology Meter:** The screen displays a timeline slider. As the player reads text blocks, the slider advances from 1299 toward 1922.
2.  **End of Chapter Reinforcement:** Once a chapter ends, the player faces a 3-question evaluation block.

### Example Quiz UI Configuration
*   **Question Design:** Text-only, 3 multi-choice selections.
*   **Non-Punitive Rule:** Wrong answers point the player back to the passage where the event was described instead of locking out progress. Correct answers add `+50` bonus score.

### Dynamic Video Integrations
*   Instead of rendering standard YouTube widgets inside WebViews (which bloat mobile builds), use Godot's OS system helper to open local YouTube apps, maintaining a lightweight build footprint:
```gdscript
func _on_video_button_pressed(youtube_video_id: String) -> void:
    var full_url = "https://www.youtube.com/watch?v=" + youtube_video_id
    OS.shell_open(full_url)
```

---

## 6. Implementation Master Prompt for Godot Development

Copy and paste this prompt directly into your developer workflow or AI coding assistant to create the game logic step by step:

```text
Act as an expert Godot 4.x developer. We are creating a lightweight, portrait-oriented educational timeline game about the Ottoman Empire.

Step 1: Build the UI Canvas Architecture
Create a Control scene named TimelineScreen. Use a standard layout:
- A MarginContainer providing a clean 20px padding.
- A VBoxContainer containing:
  - An Upper Header Label displaying the current Sultan's name and reign dates.
  - A RichTextLabel named ContentLabel with BBCode enabled for clean typography, showing descriptions of wives and major battles.
  - A bottom HBoxContainer with back/forward buttons navigating chronologically through the dynastic tree array.

Step 2: Add Time-Tracking Logic
Write a GDScript attached to the main node that uses `_process(delta)` to continuously increment a `study_time` variable. Save this value securely to the local drive every time a user moves to a new sultan or finishes a chapter.

Step 3: Build a Lightweight Quiz Template
Create a 3-button multi-choice interface overlay. When a user finishes an era chapter, fade out the text timeline and show the quiz screen. If a user picks an incorrect answer, highlight the right passage context without displaying a failure alert.

Ensure the entire architecture remains completely modular, pulling details directly out of a structured JSON configuration file.
```
