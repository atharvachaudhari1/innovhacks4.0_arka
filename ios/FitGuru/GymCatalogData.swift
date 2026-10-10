import Foundation

struct GymCatalogRepository {
    static let equipmentList: [EquipmentWithExercise] = [
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "bench_press",
                name: "Bench Press",
                icon: "🏋️",
                what: "Standard flat Olympic bench and barbell station for horizontal pushing strength.",
                labels: ["Chest", "Triceps", "Anterior Deltoids"],
                exercises: ["barbell_bench_press"],
                category: "Free Weights"
            ),
            primaryExercise: ExerciseGuide(
                id: "barbell_bench_press",
                name: "Flat Barbell Bench Press",
                muscles: ["Pectoralis Major", "Triceps Brachii", "Anterior Deltoids"],
                level: "Intermediate",
                plan: "3 sets × 8–10 reps • 90s rest",
                setup: [
                    "Lie flat with eyes directly under the racked barbell.",
                    "Plant feet firmly on the floor and pinch shoulder blades together.",
                    "Grip bar slightly wider than shoulder-width with thumbs wrapped.",
                    "Unrack bar and stabilize with locked elbows over upper chest."
                ],
                steps: [
                    "Inhale and lower bar under control to mid-chest (nipple line).",
                    "Lightly touch sternum without bouncing the weight.",
                    "Drive feet into the ground and press bar straight up to lockout.",
                    "Exhale at the top of the repetition."
                ],
                mistakes: [
                    "Bouncing the barbell off the chest.",
                    "Flaring elbows out at 90° (keep them at 45° to protect rotator cuffs).",
                    "Lifting hips/buttocks off the bench surface during heavy pressing."
                ],
                safety: "Always use safety bar catches or a spotter on heavy attempts.",
                cameraTip: "Position camera 45° from side showing shoulder to elbow arc.",
                workoutType: "BENCH_PRESS"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "squat_rack",
                name: "Squat Rack / Power Rack",
                icon: "🏋️",
                what: "Multi-functional cage with adjustable safety pins for squats and compound lifts.",
                labels: ["Quadriceps", "Glutes", "Hamstrings", "Core"],
                exercises: ["barbell_back_squat"],
                category: "Free Weights"
            ),
            primaryExercise: ExerciseGuide(
                id: "barbell_back_squat",
                name: "Barbell Back Squat",
                muscles: ["Quadriceps", "Gluteus Maximus", "Adductors", "Erector Spinae"],
                level: "Intermediate",
                plan: "4 sets × 8 reps • 2 min rest",
                setup: [
                    "Set bar height just below shoulder level (mid-chest).",
                    "Set safety horizontal bars at your deep squat depth.",
                    "Step under bar, rest across upper traps, and grip firmly.",
                    "Unrack with tall posture, take 2 steps back, feet shoulder-width."
                ],
                steps: [
                    "Take a deep breath into abdomen, brace your core.",
                    "Hinge at hips and bend knees simultaneously, pushing knees outward.",
                    "Descend until hip crease is parallel with or below knees.",
                    "Drive through whole foot to stand back up, exhaling at the top."
                ],
                mistakes: [
                    "Knees caving inward (valgus collapse).",
                    "Heels lifting off the ground.",
                    "Rounding lower back at the bottom of the squat."
                ],
                safety: "Ensure safety catch pins are adjusted before loading heavy plates.",
                cameraTip: "Position phone sideways 8 feet away showing side profile from head to toes.",
                workoutType: "SQUAT"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "lat_pulldown",
                name: "Lat Pulldown Machine",
                icon: "🔽",
                what: "Overhead cable pulley station with wide-grip bar targeting back width.",
                labels: ["Latissimus Dorsi", "Biceps", "Rhomboids"],
                exercises: ["lat_pulldown_wide"],
                category: "Upper Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "lat_pulldown_wide",
                name: "Wide-Grip Lat Pulldown",
                muscles: ["Latissimus Dorsi", "Biceps Brachii", "Rear Delts", "Mid Traps"],
                level: "Beginner",
                plan: "3 sets × 12 reps • 60s rest",
                setup: [
                    "Adjust thigh pad so legs are securely wedged with feet flat on the floor.",
                    "Grip bar with overhand grip wider than shoulder width.",
                    "Sit down and allow arms to extend overhead."
                ],
                steps: [
                    "Pull shoulder blades down and back (depress scapula).",
                    "Pull bar smoothly down toward upper chest (collarbone).",
                    "Squeeze lats firmly at the bottom for 1 second.",
                    "Slowly return bar overhead with 2–3 second eccentric tempo."
                ],
                mistakes: [
                    "Swinging torso backward excessively to build momentum.",
                    "Pulling bar behind the neck (harms cervical spine).",
                    "Letting weight stack slam between repetitions."
                ],
                safety: "Select appropriate weight that enables smooth 3-second returns.",
                cameraTip: "Position camera facing front or 45-degree angle showing elbow flexion.",
                workoutType: "LAT_PULLDOWN"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "leg_press",
                name: "Leg Press Machine",
                icon: "🦵",
                what: "45-degree angled sled machine for heavy quadriceps and leg volume with back support.",
                labels: ["Quadriceps", "Glutes", "Hamstrings"],
                exercises: ["leg_press_45"],
                category: "Lower Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "leg_press_45",
                name: "45° Incline Leg Press",
                muscles: ["Quadriceps", "Gluteus Maximus", "Adductor Magnus"],
                level: "Beginner",
                plan: "3 sets × 12 reps • 90s rest",
                setup: [
                    "Sit back completely with hips and spine glued to the backrest.",
                    "Place feet shoulder-width on the platform center.",
                    "Disengage safety side handles with straight legs (never hyper-lock knees)."
                ],
                steps: [
                    "Inhale and lower platform until knees reach 90 degrees.",
                    "Keep lower back flat against pad without pelvic tuck.",
                    "Press through heels and midfoot back to starting position.",
                    "Stop just before complete knee hyperextension."
                ],
                mistakes: [
                    "Locking knees forcefully at top of extension (joint damage risk).",
                    "Lower back peeling off the back pad at maximum depth.",
                    "Placing feet too low causing excessive shear on kneecaps."
                ],
                safety: "Keep hands on side safety levers during the movement.",
                cameraTip: "Side angle view showing leg flexion angle from hip to ankle.",
                workoutType: "LEG_PRESS"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "seated_cable_row",
                name: "Seated Cable Row",
                icon: "🚣",
                what: "Low cable pulley with footplates and close-grip V-bar for mid-back thickness.",
                labels: ["Rhomboids", "Middle Trapezius", "Latissimus Dorsi", "Biceps"],
                exercises: ["seated_cable_row_vbar"],
                category: "Upper Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "seated_cable_row_vbar",
                name: "Seated V-Grip Cable Row",
                muscles: ["Rhomboids", "Middle Trapezius", "Latissimus Dorsi", "Biceps"],
                level: "Beginner",
                plan: "3 sets × 12 reps • 60s rest",
                setup: [
                    "Sit on bench, place feet on footrests with knees slightly bent.",
                    "Reach forward, grip V-handle, and push back with tall upright torso.",
                    "Keep slight natural arch in lower back and chest tall."
                ],
                steps: [
                    "Pull handle toward belly button while driving elbows backwards.",
                    "Pinch shoulder blades together tightly at peak contraction.",
                    "Hold for 1 count, then extend arms forward under full control.",
                    "Maintain stable torso angle without rocking forward and back."
                ],
                mistakes: [
                    "Excessive swaying and using lower-back momentum.",
                    "Shrugging shoulders up to ears instead of back and down.",
                    "Rounding thoracic spine during the eccentric stretch."
                ],
                safety: "Never round lower spine when picking up or racking weight.",
                cameraTip: "Side profile showing spine alignment and elbow retraction.",
                workoutType: "LAT_PULLDOWN"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "chest_press",
                name: "Chest Press Machine",
                icon: "🏋️",
                what: "Guided machine track for safe, stable horizontal pressing.",
                labels: ["Pectorals", "Triceps", "Anterior Deltoids"],
                exercises: ["machine_chest_press"],
                category: "Upper Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "machine_chest_press",
                name: "Seated Machine Chest Press",
                muscles: ["Pectoralis Major", "Triceps", "Anterior Deltoids"],
                level: "Beginner",
                plan: "3 sets × 12 reps • 60s rest",
                setup: [
                    "Adjust seat height so handles align with mid-chest (nipple line).",
                    "Sit back with shoulder blades pressed against the backrest.",
                    "Grip handles firmly and plant feet flat on the floor."
                ],
                steps: [
                    "Press handles forward smoothly until arms are extended.",
                    "Keep wrists neutral without backwards extension.",
                    "Pause briefly, then lower handles back with control.",
                    "Stop just before weight plates collide."
                ],
                mistakes: [
                    "Seat too high or low putting stress on shoulder capsule.",
                    "Hyperextending elbows abruptly at full extension.",
                    "Leaning forward off the backrest."
                ],
                safety: "Use the foot pedal assist if equipped to unrack heavy weights safely.",
                cameraTip: "Side-front view showing arm drive and chest extension.",
                workoutType: "BENCH_PRESS"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "shoulder_press",
                name: "Shoulder Press Machine",
                icon: "🙌",
                what: "Fixed trajectory overhead press machine isolating the deltoid heads.",
                labels: ["Anterior Deltoids", "Medial Deltoids", "Triceps"],
                exercises: ["machine_overhead_press"],
                category: "Upper Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "machine_overhead_press",
                name: "Seated Machine Overhead Press",
                muscles: ["Deltoids (Anterior & Lateral)", "Triceps", "Upper Traps"],
                level: "Beginner",
                plan: "3 sets × 10 reps • 60s rest",
                setup: [
                    "Adjust seat so handles start at around ear/chin level.",
                    "Sit upright with lower back supported against backrest.",
                    "Grip handles with palms facing forward or neutral."
                ],
                steps: [
                    "Press handles vertically overhead until arms are nearly straight.",
                    "Exhale during the concentric press upward.",
                    "Pause at top, then descend with 2-second eccentric control.",
                    "Lower until handles return to chin level."
                ],
                mistakes: [
                    "Arching lower back excessively off the back pad.",
                    "Pressing unevenly with one dominant side.",
                    "Letting elbows flare excessively backward."
                ],
                safety: "Ensure pins are securely locked into the weight stack.",
                cameraTip: "Front facing camera showing overhead arm symmetry.",
                workoutType: "SHOULDER_PRESS"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "leg_extension",
                name: "Leg Extension Machine",
                icon: "🦵",
                what: "Single-joint machine isolating the quadriceps through knee extension.",
                labels: ["Quadriceps (Rectus Femoris, Vasti)"],
                exercises: ["seated_leg_extension"],
                category: "Lower Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "seated_leg_extension",
                name: "Seated Leg Extension",
                muscles: ["Quadriceps Femoris"],
                level: "Beginner",
                plan: "3 sets × 15 reps • 60s rest",
                setup: [
                    "Adjust backrest so knees align directly with machine pivot axis.",
                    "Adjust shin pad so it rests on lower shins right above ankles.",
                    "Hold side handles firmly to keep hips seated."
                ],
                steps: [
                    "Extend knees smoothly to raise shin pad until legs are straight.",
                    "Squeeze quadriceps hard at top of contraction for 1 second.",
                    "Slowly lower weight back down over 3 seconds.",
                    "Stop just before the stack touches down."
                ],
                mistakes: [
                    "Kicking up explosively using momentum instead of quad muscle.",
                    "Hips lifting off the seat pad.",
                    "Setting shin pad too high on the shins."
                ],
                safety: "Keep tempo slow and controlled to protect the patellar tendon.",
                cameraTip: "Side camera angle showing knee angle progression.",
                workoutType: "LEG_PRESS"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "leg_curl",
                name: "Leg Curl Machine",
                icon: "🦵",
                what: "Knee flexion machine isolating the posterior hamstring complex.",
                labels: ["Hamstrings", "Gastrocnemius"],
                exercises: ["seated_leg_curl"],
                category: "Lower Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "seated_leg_curl",
                name: "Seated Hamstring Leg Curl",
                muscles: ["Hamstrings (Biceps Femoris, Semitendinosus)"],
                level: "Beginner",
                plan: "3 sets × 12 reps • 60s rest",
                setup: [
                    "Align knee joints with pivot point indicator on the machine.",
                    "Lower thigh restraint pad snugly over lower thighs.",
                    "Position heel pad just below Achilles tendon."
                ],
                steps: [
                    "Curl heels downward and under the seat as far as possible.",
                    "Squeeze hamstrings tightly at peak contraction.",
                    "Slowly resist weight stack on the way back up.",
                    "Maintain tall posture with core engaged."
                ],
                mistakes: [
                    "Letting thigh restraint loosen and lift.",
                    "Jerking torso forward on initiation.",
                    "Incomplete range of motion at bottom."
                ],
                safety: "Warm up with light weight to prevent hamstring cramps.",
                cameraTip: "Side profile showing knee flexion degree.",
                workoutType: "LEG_PRESS"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "cable_machine",
                name: "Cable Machine / Functional Trainer",
                icon: "⚡",
                what: "Dual adjustable pulley system providing constant tension through any movement plane.",
                labels: ["Chest", "Arms", "Back", "Core"],
                exercises: ["cable_chest_fly"],
                category: "Upper Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "cable_chest_fly",
                name: "Standing Cable Chest Fly",
                muscles: ["Pectoralis Major (Sternal & Clavicular)", "Anterior Deltoids"],
                level: "Intermediate",
                plan: "3 sets × 15 reps • 60s rest",
                setup: [
                    "Set pulleys at chest or shoulder height with D-handles attached.",
                    "Grip handles, take a step forward into a staggered stance.",
                    "Keep slight bend in elbows and lean forward slightly from hips."
                ],
                steps: [
                    "Bring hands together in front of chest in a wide hugging arc.",
                    "Squeeze chest muscles intensely as hands meet.",
                    "Slowly reverse the motion until mild stretch in pecs is felt.",
                    "Maintain stable stance throughout without rocking."
                ],
                mistakes: [
                    "Turning the fly into a pressing motion by bending elbows too much.",
                    "Letting arms fly back too far straining shoulders.",
                    "Shifting stance during the set."
                ],
                safety: "Ensure both pulley height pins are locked at identical levels.",
                cameraTip: "Front facing view showing hand convergence and chest contraction.",
                workoutType: "PUSH_UP"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "smith_machine",
                name: "Smith Machine",
                icon: "🏗️",
                what: "Barbell fixed on vertical or slightly angled guide rails with safety lock pegs.",
                labels: ["Full Body", "Squats", "Presses", "Lunges"],
                exercises: ["smith_machine_squat"],
                category: "Free Weights"
            ),
            primaryExercise: ExerciseGuide(
                id: "smith_machine_squat",
                name: "Smith Machine Squat",
                muscles: ["Quadriceps", "Glutes", "Hamstrings"],
                level: "Beginner",
                plan: "3 sets × 10 reps • 90s rest",
                setup: [
                    "Set bar at collarbone height and adjust bottom safety stops.",
                    "Step under bar across upper traps and rotate wrists to unrack.",
                    "Place feet slightly forward from bar line for upright torso."
                ],
                steps: [
                    "Descend by bending knees and sitting back into hips.",
                    "Go down to parallel thigh depth.",
                    "Drive through heels back to top.",
                    "Rotate wrists forward to re-rack bar into hooks at finish."
                ],
                mistakes: [
                    "Forgetting to rotate wrists to securely hook bar when finished.",
                    "Placing feet directly under bar stressing knees excessively.",
                    "Rounding back off the vertical axis."
                ],
                safety: "Always set the mechanical safety stop collars before beginning.",
                cameraTip: "Side profile showing spine angle and knee depth.",
                workoutType: "SQUAT"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "dumbbells",
                name: "Dumbbell Rack",
                icon: "🦾",
                what: "Pairs of free weights from 5 lbs to 100+ lbs for unilateral and functional lifts.",
                labels: ["Arms", "Shoulders", "Chest", "Legs"],
                exercises: ["dumbbell_bicep_curl"],
                category: "Free Weights"
            ),
            primaryExercise: ExerciseGuide(
                id: "dumbbell_bicep_curl",
                name: "Standing Dumbbell Bicep Curls",
                muscles: ["Biceps Brachii", "Brachialis", "Brachioradialis"],
                level: "Beginner",
                plan: "3 sets × 12 reps • 60s rest",
                setup: [
                    "Stand tall holding a dumbbell in each hand at arms length.",
                    "Keep elbows pinned close to your torso sides.",
                    "Palms facing inward (neutral grip) or facing forward."
                ],
                steps: [
                    "Curl dumbbells upward while rotating forearms (supination).",
                    "Raise until dumbbells are near shoulder level.",
                    "Squeeze biceps firmly at the top for 1 count.",
                    "Lower under control over 2–3 seconds back to dead hang."
                ],
                mistakes: [
                    "Swinging torso back and forth using momentum.",
                    "Allowing elbows to flare forward or outward.",
                    "Dropping weights quickly without eccentric control."
                ],
                safety: "Pick weights up with a flat back using legs, not lumbar spine.",
                cameraTip: "Front or side view showing elbow position and forearm angle.",
                workoutType: "BICEP_CURL"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "pec_deck",
                name: "Pec Deck (Chest Fly) Machine",
                icon: "🦋",
                what: "Machine with dual rotating levers isolating the pectoral muscles safely.",
                labels: ["Chest", "Anterior Deltoids"],
                exercises: ["machine_pec_fly"],
                category: "Upper Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "machine_pec_fly",
                name: "Machine Pec Deck Fly",
                muscles: ["Pectoralis Major"],
                level: "Beginner",
                plan: "3 sets × 12 reps • 60s rest",
                setup: [
                    "Adjust seat so handles or pads align with mid-chest.",
                    "Keep spine flat against backrest and feet planted firmly.",
                    "Grip handles with elbows slightly bent."
                ],
                steps: [
                    "Bring levers together in front of chest in a smooth arc.",
                    "Hold peak contraction for 1 second with maximum squeeze.",
                    "Slowly allow levers to return back until mild chest stretch.",
                    "Keep shoulders depressed without shrugging."
                ],
                mistakes: [
                    "Setting starting position too far back straining shoulder capsule.",
                    "Bending and straightening elbows during the rep.",
                    "Leaning forward off the backrest."
                ],
                safety: "Use the foot release lever to enter and exit the stretch safely.",
                cameraTip: "Front angle camera showing hand convergence and chest contraction.",
                workoutType: "PUSH_UP"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "deadlift_platform",
                name: "Deadlift Platform",
                icon: "🏋️‍♂️",
                what: "Heavy wooden & rubber lifting deck with Olympic bar and bumper plates.",
                labels: ["Posterior Chain", "Hamstrings", "Glutes", "Erector Spinae"],
                exercises: ["barbell_deadlift"],
                category: "Free Weights"
            ),
            primaryExercise: ExerciseGuide(
                id: "barbell_deadlift",
                name: "Conventional Barbell Deadlift",
                muscles: ["Gluteus Maximus", "Hamstrings", "Erector Spinae", "Trapezius", "Latissimus Dorsi"],
                level: "Advanced",
                plan: "3 sets × 5 reps • 3 min rest",
                setup: [
                    "Stand with feet hip-width apart, barbell over midfoot (1 inch from shins).",
                    "Hinge at hips, bend knees slightly, grip bar just outside legs.",
                    "Pull slack out of bar, flatten back, and engage lats like squeezing oranges."
                ],
                steps: [
                    "Take big breath, brace core, push floor away through feet.",
                    "Bar stays in continuous contact with shins and thighs as you stand.",
                    "Lock out at top by squeezing glutes (do not hyperextend lower back).",
                    "Hinge hips back to lower bar along thighs to floor under control."
                ],
                mistakes: [
                    "Rounding lumbar spine under heavy loads.",
                    "Letting bar drift forward away from the body.",
                    "Jerking the bar off the floor before setting tension."
                ],
                safety: "Drop or reset bar if lower back rounds during a repetition.",
                cameraTip: "Side profile 8-10 feet away showing full spine line and hip hinge.",
                workoutType: "DEADLIFT"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "pullup_bar",
                name: "Pull-Up & Chin-Up Bar",
                icon: "🧗",
                what: "Overhead rigid bar with multi-grip handles for bodyweight vertical pulling.",
                labels: ["Latissimus Dorsi", "Biceps", "Forearms", "Core"],
                exercises: ["bodyweight_pullup"],
                category: "Upper Body"
            ),
            primaryExercise: ExerciseGuide(
                id: "bodyweight_pullup",
                name: "Strict Bodyweight Pull-Up",
                muscles: ["Latissimus Dorsi", "Biceps Brachii", "Brachialis", "Lower Trapezius"],
                level: "Intermediate",
                plan: "3 sets × 6–10 reps • 90s rest",
                setup: [
                    "Hang from bar with overhand grip slightly wider than shoulder width.",
                    "Start in full dead hang with arms straight and shoulders relaxed."
                ],
                steps: [
                    "Engage scapula by pulling shoulder blades down and back.",
                    "Drive elbows down toward hips and pull chest toward the bar.",
                    "Continue pulling until chin clears the height of the bar.",
                    "Lower yourself smoothly back to full dead hang over 2 seconds."
                ],
                mistakes: [
                    "Kicking legs or kipping for momentum.",
                    "Partial reps without full elbow extension at the bottom.",
                    "Craning neck upward to touch bar instead of pulling chest up."
                ],
                safety: "Use resistance bands or assisted machine if unable to perform strict reps.",
                cameraTip: "Rear or front camera showing chin height and full lockout.",
                workoutType: "PULL_UP"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "treadmill",
                name: "Treadmill",
                icon: "🏃",
                what: "Motorized continuous belt for walking, interval running, and cadence drills.",
                labels: ["Cardiovascular System", "Legs", "Cadence"],
                exercises: ["running_cadence_drill"],
                category: "Cardio"
            ),
            primaryExercise: ExerciseGuide(
                id: "running_cadence_drill",
                name: "Target Cadence Running Drill",
                muscles: ["Cardiovascular Endurance", "Calves", "Quadriceps"],
                level: "All Levels",
                plan: "20 min run • 165–175 SPM target",
                setup: [
                    "Attach safety emergency stop clip to clothing.",
                    "Start treadmill at walking pace to warm up ankles and knees.",
                    "Mount belt smoothly when speed stabilizes."
                ],
                steps: [
                    "Maintain tall posture with slight forward lean from ankles.",
                    "Land with midfoot underneath your center of mass.",
                    "Keep strides short and rapid targeting 165–175 steps per minute.",
                    "Breathe rhythmically in sync with foot strikes."
                ],
                mistakes: [
                    "Overstriding with heavy heel strikes in front of body.",
                    "Looking down at feet causing neck fatigue.",
                    "Holding onto side handrails while running."
                ],
                safety: "Always attach safety tether clip to shut off motor immediately if slipping.",
                cameraTip: "Side view showing foot strike location and step turnover cadence.",
                workoutType: "RUNNING"
            )
        ),
        EquipmentWithExercise(
            machine: MachineGuide(
                id: "rowing_machine",
                name: "Rowing Machine (Ergometer)",
                icon: "🚣",
                what: "Air-resistance or magnetic flywheel simulating competitive sculling.",
                labels: ["Full Body Cardio", "Legs", "Back", "Core"],
                exercises: ["indoor_rowing"],
                category: "Cardio"
            ),
            primaryExercise: ExerciseGuide(
                id: "indoor_rowing",
                name: "Indoor Rowing Stroke",
                muscles: ["Quadriceps", "Glutes", "Hamstrings", "Latissimus Dorsi", "Core"],
                level: "Beginner",
                plan: "15 min interval row • 24–28 SPM",
                setup: [
                    "Secure feet firmly in footplates with straps across ball of foot.",
                    "Set damper resistance to 3–5 for optimal aerobic efficiency.",
                    "Grip handle with relaxed overhand grip."
                ],
                steps: [
                    "Catch: Shins vertical, torso tilted forward at 1 o'clock.",
                    "Drive: Push aggressively with legs (60%), swing back (20%), pull arms (20%).",
                    "Finish: Handle at lower ribs, torso leaning back slightly at 11 o'clock.",
                    "Recovery: Arms extend, torso swings forward, knees bend back to catch."
                ],
                mistakes: [
                    "Bending knees before arms extend forward on the recovery.",
                    "Pulling with arms before legs have driven.",
                    "Slouching back and rounding shoulders at the catch."
                ],
                safety: "Drive through legs first, never initiate drive with lower back.",
                cameraTip: "Side profile showing leg-body-arm sequence.",
                workoutType: "LAT_PULLDOWN"
            )
        )
    ]
}
