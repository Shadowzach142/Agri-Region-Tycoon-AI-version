# Data.gd
# Autoload singleton containing static game data dictionaries

extends Node

# Current selected region (set by MainMenu)
var current_region: String = "cotabato"

# Selected game mode: "campaign" (timed RTS sprint) or "career" (endless persistent farm with save & load)
var game_mode: String = "campaign"

const GAME_MODES = {
	"campaign": {
		"id": "campaign",
		"title": "TIMED PVE CAMPAIGN",
		"subtitle": "RTS Score Attack Challenge",
		"badge": "⏱️ SPRINT RUN",
		"desc": "Race against the clock in a 30, 60, or 90-day season. Maximize export revenues, achieve quality grades, and climb the Tycoon Prestige leaderboards!"
	},
	"career": {
		"id": "career",
		"title": "CAREER / ENDLESS TYCOON",
		"subtitle": "Persistent Farm Builder",
		"badge": "🌾 SAVE & LOAD",
		"desc": "Build and expand your agricultural empire at your own pace with no time limits. Full support for saving your farm progress and loading it anytime to resume right where you left off!"
	}
}

# Selected campaign duration in days (set by MainMenu: 30, 60, or 90)
var selected_season_days: int = 60

const SEASON_MODES = {
	30: {
		"title": "Quick Sprint",
		"subtitle": "30 Days (1 Month)",
		"badge": "⚡ SPRINT",
		"desc": "Fast-paced harvest challenge — maximize quick Palay & Corn turnover!"
	},
	60: {
		"title": "Standard Campaign",
		"subtitle": "60 Days (2 Months)",
		"badge": "⭐ STANDARD",
		"desc": "Classic RTS agribusiness season — balanced infrastructure & full crop cycles."
	},
	90: {
		"title": "Full Season",
		"subtitle": "90 Days (3 Months)",
		"badge": "👑 FULL QUARTER",
		"desc": "Grand agricultural expansion — mega-infrastructure, deep export streaks, & highest scores."
	}
}

# Regions with default soil moisture (0-100) and hazard probabilities (0-1)
const REGIONS = {
	"cotabato": {
		"display_name": "Cotabato Basin (Central Floodplains)",
		"soil_moisture": 65,
		"specialty": "Rice Paddies & Wetland Agriculture",
		"description": "The fertile rice bowl of Central Mindanao, fed by the Pulangi river basin with rich alluvial soils for continuous cultivation.",
		"pros": [
			"Rich alluvial soil with high natural moisture (65%)",
			"Accelerated Palay growth & bumper harvest yields",
			"Naturally protected from severe regional droughts"
		],
		"cons": [
			"Vulnerable to flash floods & river overflow",
			"Golden Apple Snail (Kuhol) infestations in paddies",
			"Extreme over-saturation (>90% moisture) rots crops"
		],
		"hazards": {
			"flash_flood": 0.15,
			"landslide": 0.03,
			"el_nino_drought": 0.06,
		},
	},
	"south_cotabato": {
		"display_name": "South Cotabato Highlands (Mount Matutum)",
		"soil_moisture": 55,
		"specialty": "Highland Specialty Crops, Coffee & Pineapple",
		"description": "Cool volcanic plateaus surrounding Mount Matutum and Lake Sebu, renowned for premium Coffee, Corn, and export Pineapples.",
		"pros": [
			"Cool mountain climate prevents crop heat stress",
			"Volcanic soil yields +20% bonus on Coffee & Pineapple",
			"Naturally sheltered from low-elevation flash floods"
		],
		"cons": [
			"Steep mountain slopes carry Landslide risks (12%)",
			"High vulnerability to Fusarium Wilt (Panama Disease)",
			"Winding mountain roads increase logistics costs"
		],
		"hazards": {
			"flash_flood": 0.08,
			"landslide": 0.12,
			"el_nino_drought": 0.05,
		},
	},
	"sarangani": {
		"display_name": "Sarangani Littoral Coast (Alabel / Glan)",
		"soil_moisture": 45,
		"specialty": "Arid Coastal Farming & Plantation Perennials",
		"description": "Sun-drenched agrarian coastal plains along Sarangani Bay, ideal for hardy Coconut Palms and deep-sea export trade.",
		"pros": [
			"Ideal tropical climate for Coconut & Banana groves",
			"Direct coastal shipping access with low freight costs",
			"Zero risk of landslides or river inundation"
		],
		"cons": [
			"Severe El Niño drought risk (14%) and heatwaves",
			"Low baseline moisture (45%) requires irrigation",
			"Frequent Fall Armyworm outbreaks during dry spells"
		],
		"hazards": {
			"flash_flood": 0.05,
			"landslide": 0.02,
			"el_nino_drought": 0.14,
		},
	},
	"sultan_kudarat": {
		"display_name": "Sultan Kudarat Valley (Tacurong Corridor)",
		"soil_moisture": 58,
		"specialty": "Sugarcane Plantations & Mechanized Grains",
		"description": "Expansive agricultural flatlands and open corridors suited for large-scale Sugarcane plantations and mechanized grains.",
		"pros": [
			"Broad flat plains maximize tractor & harvester speed",
			"Rich loam gives +20% bonus on Sugarcane & Corn",
			"High harvest volume with cheaper building layout"
		],
		"cons": [
			"Dense monoculture accelerates Armyworm & Bug spread",
			"Heavy machinery requires frequent fuel & maintenance",
			"Oversaturating local hubs temporarily depresses prices"
		],
		"hazards": {
			"flash_flood": 0.09,
			"landslide": 0.03,
			"el_nino_drought": 0.08,
		},
	},
	"general_santos": {
		"display_name": "General Santos City (Agro-Industrial Hub)",
		"soil_moisture": 50,
		"specialty": "Industrial Seaport Processing & Cold Storage",
		"description": "The trade capital of Region 12, featuring direct seaport access, industrial cold storage, and export packaging hubs.",
		"pros": [
			"Direct seaport access with top export rates (+35%)",
			"Industrial Cold Storage halts harvest spoilage",
			"Fast access to high-tier weather gear & tech"
		],
		"cons": [
			"Higher worker wages and urban operating costs",
			"Coastal humidity favors Fusarium Wilt infections",
			"Seaport container inspection & freight surcharges"
		],
		"hazards": {
			"flash_flood": 0.06,
			"landslide": 0.02,
			"el_nino_drought": 0.10,
		},
	},
}

# Crop definitions
const CROPS = {
	"palay": {
		"display_name": "Palay (Rice)",
		"icon": "🌾",
		"footprint": Vector2i(1, 1),
		"growth_days": 15,
		"regrowth_days": 0,
		"is_perennial": false,
		"harvest_duration": 1.0,
		"yield_quantity": 100,
		"water_min": 70,
		"water_max": 90,
		"heat_min": 20,
		"heat_max": 35,
		"base_price": 100,
		"pests": ["kuhol", "rice_black_bug"],
		"seed_cost": 25,
		"description": "Thrives in wetland paddies (70-90% moisture). Halts growth if <30%. Severe waterlogging (>95%) rots roots.",
	},
	"yellow_corn": {
		"display_name": "Yellow Corn",
		"icon": "🌽",
		"footprint": Vector2i(1, 1),
		"growth_days": 25,
		"regrowth_days": 0,
		"is_perennial": false,
		"harvest_duration": 1.1,
		"yield_quantity": 100,
		"water_min": 30,
		"water_max": 60,
		"heat_min": 22,
		"heat_max": 45,
		"base_price": 120,
		"pests": ["armyworm"],
		"seed_cost": 30,
		"description": "Hardy cereal crop (30-60% moisture). Highly resilient against heat up to 45°C. Vulnerable to armyworms.",
	},
	"sugarcane": {
		"display_name": "Sugar Cane",
		"icon": "🎋",
		"footprint": Vector2i(1, 1),
		"growth_days": 28,
		"regrowth_days": 0,
		"is_perennial": false,
		"harvest_duration": 1.4,
		"yield_quantity": 120,
		"water_min": 50,
		"water_max": 80,
		"heat_min": 22,
		"heat_max": 38,
		"base_price": 95,
		"pests": ["armyworm", "fusarium_wilt"],
		"seed_cost": 30,
		"description": "Vigorous river crop (50-80% moisture). Thrives in full sun; yields high raw biomass (120 units).",
	},
	"pineapple": {
		"display_name": "Smooth Cayenne Pineapple",
		"icon": "🍍",
		"footprint": Vector2i(1, 1),
		"growth_days": 35,
		"regrowth_days": 0,
		"is_perennial": false,
		"harvest_duration": 1.3,
		"yield_quantity": 100,
		"water_min": 35,
		"water_max": 65,
		"heat_min": 20,
		"heat_max": 36,
		"base_price": 160,
		"pests": ["fusarium_wilt", "armyworm"],
		"seed_cost": 40,
		"description": "High-value export fruit (35-65% moisture). Thrives in volcanic soils; sensitive to standing flood rot.",
	},
	"arabica_coffee": {
		"display_name": "Arabica Coffee",
		"icon": "☕",
		"footprint": Vector2i(1, 1),
		"growth_days": 40,
		"regrowth_days": 14,
		"is_perennial": true,
		"harvest_duration": 1.3,
		"yield_quantity": 100,
		"water_min": 35,
		"water_max": 70,
		"heat_min": 18,
		"heat_max": 30,
		"base_price": 200,
		"pests": ["kuhol", "fusarium_wilt"],
		"seed_cost": 50,
		"description": "High-margin perennial shrub (35-70% moisture). Regrows cherries indefinitely without replanting.",
	},
	"banana": {
		"display_name": "Cavendish Banana",
		"icon": "🍌",
		"footprint": Vector2i(2, 2),
		"growth_days": 50,
		"regrowth_days": 18,
		"is_perennial": true,
		"harvest_duration": 2.2,
		"yield_quantity": 400,
		"water_min": 55,
		"water_max": 85,
		"heat_min": 24,
		"heat_max": 36,
		"base_price": 90,
		"pests": ["fusarium_wilt"],
		"seed_cost": 140,
		"description": "2×2 plantation grove (55-85% moisture). Yields 400 units every 18d indefinitely without replanting.",
	},
	"coconut": {
		"display_name": "Tall Coconut Palm",
		"icon": "🥥",
		"footprint": Vector2i(2, 2),
		"growth_days": 50,
		"regrowth_days": 16,
		"is_perennial": true,
		"harvest_duration": 2.4,
		"yield_quantity": 400,
		"water_min": 40,
		"water_max": 75,
		"heat_min": 20,
		"heat_max": 38,
		"base_price": 85,
		"seed_cost": 160,
		"pests": ["armyworm"],
		"description": "Durable 2×2 coastal palm (40-75% moisture). Bears buko nuts indefinitely (16d cycle) without replanting.",
	},
}

# Processed Value-Added Commodities (Agro-Industrial Milling & Refining)
const PROCESSED_GOODS = {
	"milled_rice": {
		"display_name": "Polished White Rice",
		"icon": "🍚",
		"base_price": 220,
		"is_processed": true,
		"source_crop": "palay",
		"facility": "rice_mill",
		"description": "Premium machine-milled white grain from Kiskisan Rice Mill (+120% value). Shelf-stable; never rots in storage or transit.",
	},
	"rice_bran": {
		"display_name": "Rice Bran (Darak Feed)",
		"icon": "🌾",
		"base_price": 40,
		"is_processed": true,
		"source_crop": "palay",
		"facility": "rice_mill",
		"description": "High-nutrient milling byproduct sold to regional livestock and poultry operations. Zero spoilage.",
	},
	"muscovado_sugar": {
		"display_name": "Muscovado Sugar Blocks",
		"icon": "🪵",
		"base_price": 210,
		"is_processed": true,
		"source_crop": "sugarcane",
		"facility": "sugar_mill",
		"description": "Unrefined artisanal whole cane sugar blocks from Trapiche Sugar Central. High export demand; immune to decay.",
	},
	"molasses": {
		"display_name": "Cane Molasses Syrup",
		"icon": "🍯",
		"base_price": 65,
		"is_processed": true,
		"source_crop": "sugarcane",
		"facility": "sugar_mill",
		"description": "Dense, viscous cane syrup byproduct used for fermentation and feed enrichment. Shelf-stable.",
	},
	"vco": {
		"display_name": "Virgin Coconut Oil (VCO)",
		"icon": "🥥",
		"base_price": 260,
		"is_processed": true,
		"source_crop": "coconut",
		"facility": "copra_dryer",
		"description": "Cold-pressed pure virgin coconut oil from Tapahan Copra Dryer & Press. Highly lucrative international wellness commodity.",
	},
	"copra_meal": {
		"display_name": "Copra Meal / Cake",
		"icon": "🌴",
		"base_price": 50,
		"is_processed": true,
		"source_crop": "coconut",
		"facility": "copra_dryer",
		"description": "Solid protein-rich residue from coconut oil extraction. Sold in bulk to animal feed compounders.",
	},
	"roasted_coffee": {
		"display_name": "Barako Roast Coffee",
		"icon": "☕",
		"base_price": 480,
		"is_processed": true,
		"source_crop": "arabica_coffee",
		"facility": "coffee_roastery",
		"description": "Batch drum-roasted highland Arabica beans. Premium specialty export commanding top-tier market prices.",
	},
}

# Pest definitions
const PESTS = {
	"kuhol": {
		"display_name": "Golden Apple Snail (Kuhol)",
		"spawn_trigger": {"soil_moisture_above": 80},
		"spread_rate": 0.20,
		"treatment_cost": 30,
		"description": "Spawns in oversaturated wet paddies (>80% moisture). Feeds aggressively on young rice shoots.",
	},
	"armyworm": {
		"display_name": "Fall Armyworm",
		"spawn_trigger": {"soil_moisture_below": 35},
		"spread_rate": 0.30,
		"treatment_cost": 40,
		"description": "Outbreaks during arid dry spells (<35% moisture). Rapidly strips corn and grain foliage.",
	},
	"rice_black_bug": {
		"display_name": "Rice Black Bug",
		"spawn_trigger": {"full_moon": true},
		"spread_rate": 0.15,
		"treatment_cost": 35,
		"description": "Attracted by lunar illumination during full moon cycles. Sucks sap from rice stems causing bugburn.",
	},
	"fusarium_wilt": {
		"display_name": "Fusarium Wilt (Panama Disease)",
		"spawn_trigger": {"heat_index_above": 32},
		"spread_rate": 0.10,
		"treatment_cost": 60,
		"description": "Soil-borne fungal pathogen triggered by high heat (>32°C). Permanently impairs crop quality.",
	},
}

# Market Hubs (Selling Destinations & Logistics)
const MARKET_HUBS = {
	"local_biyahero": {
		"display_name": "Local Middleman (Biyahero)",
		"distance_km": 0,
		"travel_days": 0,
		"fuel_cost": 0,
		"price_multiplier": 0.72,
		"rot_risk_percent": 0.0,
		"description": "Instant farm-gate pickup. 0 km distance, ₱0 fuel, zero road rot risk, but lowest middleman payout (72%).",
	},
	"tacurong": {
		"display_name": "Tacurong Commercial Grain Mill",
		"distance_km": 45,
		"travel_days": 1,
		"fuel_cost": 45,
		"price_multiplier": 1.05,
		"rot_risk_percent": 10.0,
		"requires_building": "tacurong_mill",
		"description": "Regional bulk grain processor. 45 km transit, ₱45 fuel cost, minor road spoilage (10% decay). Requires a Tacurong Grain Mill Depot on your farm.",
	},
	"koronadal": {
		"display_name": "Koronadal City Wholesale Market",
		"distance_km": 68,
		"travel_days": 1,
		"fuel_cost": 75,
		"price_multiplier": 1.20,
		"rot_risk_percent": 18.0,
		"requires_building": "koronadal_wholesale",
		"description": "Provincial commercial hub. 68 km transit, ₱75 fuel, moderate road rot risk (18% decay). Requires a Koronadal Wholesale Depot on your farm.",
	},
	"gensan_port": {
		"display_name": "General Santos Export Seaport",
		"distance_km": 135,
		"travel_days": 2,
		"fuel_cost": 160,
		"price_multiplier": 1.55,
		"rot_risk_percent": 35.0,
		"requires_building": "gensan_seaport",
		"description": "High-payout international export gateway. 135 km trip, ₱160 fuel, severe road rot risk (35% decay) unless preserved in Cold Storage! Requires a Seaport Terminal built on your east shore.",
	},
}

# Building definitions
const BUILDINGS = {
	"bahay_kubo": {
		"display_name": "Bahay Kubo (Farm Shack)",
		"shop_category": "housing",
		"unique": false,
		"icon": "🏠",
		"grid_size": Vector2i(2, 2),
		"cost": 200,
		"build_time": 8.0,
		"max_level": 3,
		"storage_limit": 0,
		"worker_capacity": 1,
		"description": "Expands farm housing by +1 worker capacity, unlocking additional autonomous farm laborers.",
	},
	"bodega": {
		"display_name": "Grain Silo Compound",
		"shop_category": "storage",
		"unique": false,
		"icon": "🏛️",
		"grid_size": Vector2i(2, 2),
		"cost": 500,
		"build_time": 25.0,
		"max_level": 3,
		"storage_limit": 200,
		"halts_spoilage": false,
		"description": "Corrugated steel grain silo bin compound providing 200 units of crop storage (upgrades to 400 at Lv. 2). Produce in basic silos spoils at 5% freshness per hour.",
	},
	"cold_storage": {
		"display_name": "Cold Storage Facility",
		"shop_category": "storage",
		"unique": false,
		"icon": "❄️",
		"grid_size": Vector2i(3, 3),
		"cost": 800,
		"build_time": 35.0,
		"max_level": 3,
		"storage_limit": 2000,
		"halts_spoilage": true,
		"description": "Industrial refrigeration with 2,000 units of storage. Completely halts warehouse spoilage and protects against transit road rot!",
	},
	"solar_dryer": {
		"display_name": "Solar Dryer (Bilaran)",
		"shop_category": "storage",
		"unique": false,
		"icon": "☀️",
		"grid_size": Vector2i(2, 3),
		"cost": 300,
		"build_time": 20.0,
		"max_level": 3,
		"storage_limit": 0,
		"drying_bonus": 0.25,
		"description": "Traditional concrete sun-drying pavement. Boosts harvested grain quality and market selling value by +25%!",
	},
	"bayanihan_center": {
		"display_name": "Biyahero Trading Post",
		"shop_category": "trade",
		"unique": true,
		"icon": "🤝",
		"grid_size": Vector2i(2, 2),
		"cost": 350,
		"build_time": 12.0,
		"max_level": 1,
		"storage_limit": 0,
		"biyahero_price_bonus": 0.08,
		"description": "A roadside bayanihan post where the local biyahero (middleman) loads his truck. One-time purchase: improves the Local Middleman's payout by +8% (72% → 80%) with the same instant, zero-rot pickup.",
	},
	"tacurong_mill": {
		"display_name": "Tacurong Grain Mill Depot",
		"shop_category": "trade",
		"unique": true,
		"icon": "🏭",
		"grid_size": Vector2i(3, 3),
		"cost": 1500,
		"build_time": 30.0,
		"max_level": 1,
		"storage_limit": 0,
		"hub_id": "tacurong",
		"hub_price_bonus": 0.06,
		"hub_rot_cut": 0.30,
		"hub_fuel_cut": 0.20,
		"description": "Your own loading depot beside the Tacurong grain mill. Unlocks the Tacurong sell hub, with +6% payout, -30% road rot and -20% fuel cost.",
	},
	"koronadal_wholesale": {
		"display_name": "Koronadal Wholesale Depot",
		"shop_category": "trade",
		"unique": true,
		"icon": "🏬",
		"grid_size": Vector2i(4, 4),
		"cost": 2800,
		"build_time": 45.0,
		"max_level": 1,
		"storage_limit": 0,
		"hub_id": "koronadal",
		"hub_price_bonus": 0.08,
		"hub_rot_cut": 0.30,
		"hub_fuel_cut": 0.25,
		"description": "Wholesale warehouse linked to the Koronadal city market. Unlocks the Koronadal sell hub, with +8% payout, -30% road rot and -25% fuel cost.",
	},
	"gensan_seaport": {
		"display_name": "General Santos Seaport Terminal",
		"shop_category": "trade",
		"unique": true,
		"icon": "⚓",
		"grid_size": Vector2i(4, 4),
		"cost": 4500,
		"build_time": 60.0,
		"max_level": 1,
		"storage_limit": 0,
		"requires_shore": true,
		"hub_id": "gensan_port",
		"hub_price_bonus": 0.12,
		"hub_rot_cut": 0.50,
		"hub_fuel_cut": 0.30,
		"description": "Container pier with a quay crane and berth for an export freighter. Must be built on the east shore so the ship can dock. Unlocks the Gensan export hub, with +12% payout, -50% road rot and -30% fuel cost.",
	},
	"climate_silo": {
		"display_name": "Climate-Controlled Silo",
		"shop_category": "storage",
		"unique": false,
		"icon": "🗼",
		"grid_size": Vector2i(3, 3),
		"cost": 1200,
		"build_time": 45.0,
		"max_level": 3,
		"storage_limit": 5000,
		"halts_spoilage": true,
		"description": "High-tech airtight grain silo with 5,000 storage capacity. Eliminates moisture rot and maintains 100% grain freshness.",
	},
	"drone_station": {
		"display_name": "Drone Command Hangar",
		"shop_category": "machinery",
		"unique": true,
		"icon": "🛸",
		"grid_size": Vector2i(2, 2),
		"cost": 800,
		"build_time": 20.0,
		"max_level": 3,
		"storage_limit": 0,
		"unlocks_drones": true,
		"description": "Automated drone hangar with telemetry antenna and solar charging pads. Unlocks drone labor in the Labor shop. Upgrading the hangar enhances drone automation (Lv.1 Plow, Lv.2 Seeder, Lv.3 Harvester). Each active drone requires 1 farmer to operate the remote control.",
	},
	"weather_station": {
		"display_name": "PAGASA Telemetry Station",
		"shop_category": "weather",
		"unique": true,
		"icon": "📡",
		"grid_size": Vector2i(3, 3),
		"cost": 450,
		"build_time": 16.0,
		"max_level": 3,
		"storage_limit": 0,
		"forecast_equipment": true,
		"description": "Meteorological monitoring station linked to regional PAGASA telemetry. Upgrading advances equipment from an AM Radio Mast (Lv. 1, 60% accuracy, 1-day forecast, 8s disaster warning) to an Automated Weather Station (Lv. 2, 90% accuracy, 3-day forecast, 12s disaster warning) and a Satellite Uplink Dish (Lv. 3, 100% accuracy, 7-day forecast, 18s disaster warning).",
	},
	"water_tower": {
		"display_name": "Irrigation Pump & Tower",
		"shop_category": "weather",
		"unique": true,
		"icon": "🚰",
		"grid_size": Vector2i(2, 2),
		"cost": 500,
		"build_time": 18.0,
		"max_level": 3,
		"storage_limit": 0,
		"irrigation_equipment": true,
		"description": "Automated farm irrigation system. Upgrading advances equipment from a Groundwater Well Pump (Lv. 1, auto-hydrates thirsty crops to min+5%, 15% drought resist) to an Elevated Water Tower (Lv. 2, maintains min+12% moisture, 25% evap reduction, 20% flood drainage) and a Solar-Powered Drip Network (Lv. 3, full-farm pressurized drip lines, precision moisture regulation, 30% disaster resilience).",
	},
	"sprinkler": {
		"display_name": "Rotary Field Sprinkler",
		"shop_category": "weather",
		"unique": false,
		"icon": "🚿",
		"grid_size": Vector2i(1, 1),
		"cost": 120,
		"build_time": 4.0,
		"max_level": 1,
		"storage_limit": 0,
		"is_sprinkler": true,
		"description": "Ground-mounted rotary impact sprinkler. Automatically sprays and hydrates surrounding crop plots every morning (3×3 diamond at Lv.1, 5×5 at Lv.2+) and suppresses daytime heat stress. Requires water pressure from an active Irrigation Pump & Tower.",
	},
	"rice_mill": {
		"display_name": "Kiskisan Rice Mill",
		"shop_category": "processing",
		"unique": false,
		"icon": "🏭",
		"grid_size": Vector2i(2, 2),
		"cost": 1400,
		"build_time": 30.0,
		"max_level": 3,
		"storage_limit": 0,
		"facility_type": "rice_mill",
		"recipe": {
			"input_crop": "palay",
			"input_qty": 100,
			"outputs": [
				{"item": "milled_rice", "qty": 75},
				{"item": "rice_bran", "qty": 25}
			]
		},
		"description": "Automated hulling and polishing mill. Every 4 hours, converts 100 raw Palay from storage into 75 Polished White Rice (₱220/ea) and 25 Rice Bran (₱40/ea). Processed goods never spoil!",
	},
	"sugar_mill": {
		"display_name": "Trapiche Sugar Central",
		"shop_category": "processing",
		"unique": false,
		"icon": "⚙️",
		"grid_size": Vector2i(3, 2),
		"cost": 1800,
		"build_time": 35.0,
		"max_level": 3,
		"storage_limit": 0,
		"facility_type": "sugar_mill",
		"recipe": {
			"input_crop": "sugarcane",
			"input_qty": 120,
			"outputs": [
				{"item": "muscovado_sugar", "qty": 70},
				{"item": "molasses", "qty": 50}
			]
		},
		"description": "Mechanized roller crusher and boiling cauldrons. Automatically processes 120 harvested Sugarcane into 70 Muscovado Sugar Blocks (₱210/ea) and 50 Cane Molasses (₱65/ea) every 4 hours.",
	},
	"copra_dryer": {
		"display_name": "Tapahan Copra Dryer & Press",
		"shop_category": "processing",
		"unique": false,
		"icon": "🔥",
		"grid_size": Vector2i(2, 2),
		"cost": 2200,
		"build_time": 40.0,
		"max_level": 3,
		"storage_limit": 0,
		"facility_type": "copra_dryer",
		"recipe": {
			"input_crop": "coconut",
			"input_qty": 200,
			"outputs": [
				{"item": "vco", "qty": 80},
				{"item": "copra_meal", "qty": 120}
			]
		},
		"description": "Biomass smokehouse kiln and mechanical expeller press. Converts 200 Coconuts into 80 Virgin Coconut Oil (₱260/ea) and 120 Copra Meal (₱50/ea) every 4 hours with 0% transit rot.",
	},
	"coffee_roastery": {
		"display_name": "Artisan Coffee Roastery",
		"shop_category": "processing",
		"unique": false,
		"icon": "☕",
		"grid_size": Vector2i(2, 2),
		"cost": 2600,
		"build_time": 45.0,
		"max_level": 3,
		"storage_limit": 0,
		"facility_type": "coffee_roastery",
		"recipe": {
			"input_crop": "arabica_coffee",
			"input_qty": 100,
			"outputs": [
				{"item": "roasted_coffee", "qty": 75}
			]
		},
		"description": "Batch drum roaster with bean grader. Processes 100 raw Arabica Coffee beans into 75 Premium Barako Roast packs (₱480/ea) every 4 hours. Unlocks immense export profits.",
	},
}

# Tech definitions
const TECH = {
	"radio_tower": {
		"display_name": "AM Radio Tower (Tier 1)",
		"forecast_days": 1,
		"accuracy": 0.60,
		"cost": 300,
		"description": "Unlocks 1-day weather forecasts with 60% accuracy. Gives early warning for sudden rain or drought.",
	},
	"aws_station": {
		"display_name": "Automated Weather Station (Tier 2)",
		"forecast_days": 3,
		"accuracy": 0.90,
		"cost": 750,
		"description": "Upgrades radar to 3-day forecasts with 90% accuracy. Allows precision irrigation scheduling.",
	},
	"iot_soil_sensor": {
		"display_name": "Satellite / IoT Sensor Net (Tier 3)",
		"forecast_days": 7,
		"accuracy": 1.00,
		"cost": 1500,
		"description": "Provides comprehensive 7-day forecasts with 100% accuracy and enables automated smart irrigation.",
	},
	"bayanihan_spirit": {
		"display_name": "Bayanihan Cooperative Spirit",
		"type": "cooperative",
		"work_speed_multiplier": 1.35,
		"cost": 600,
		"description": "Fosters community solidarity and teamwork. Unlocks Parcel Directives and boosts all workers' task speed by +35%.",
	},
	"bayanihan_coordination": {
		"display_name": "Field Coordination & Camaraderie",
		"type": "cooperative",
		"work_speed_multiplier": 1.75,
		"cost": 1800,
		"description": "Advanced cooperative coordination. Increases communal worker speed to +75% and enables automated seed replenishment.",
	},
	"kuliglig": {
		"display_name": "Bayanihan Spirit (Legacy)",
		"type": "cooperative",
		"work_speed_multiplier": 1.35,
		"cost": 600,
		"description": "Fosters community solidarity and teamwork.",
	},
	"combine_harvester": {
		"display_name": "Field Coordination (Legacy)",
		"type": "cooperative",
		"work_speed_multiplier": 1.75,
		"cost": 1800,
		"description": "Advanced cooperative coordination.",
	},
	"drip_irrigation": {
		"display_name": "Sensor-Linked Drip Irrigation",
		"type": "automation",
		"auto_water": true,
		"cost": 1500,
		"description": "Automated moisture regulation that automatically irrigates thirsty planted tiles every hour.",
	},
	"field_survey_kit": {
		"display_name": "Field Survey Kit (Diagnostic Heatmap)",
		"type": "survey",
		"cost": 400,
		"description": "Soil probes and a scanner that unlock the Diagnostic Heatmap (hotkey F): live soil moisture, crop health, ripe harvests, pest blights and sprinkler coverage across your whole farm.",
	},
}

func get_region(name: String) -> Dictionary:
	return REGIONS.get(name, REGIONS["cotabato"])

func get_crop(name: String) -> Dictionary:
	if CROPS.has(name):
		return CROPS[name]
	if PROCESSED_GOODS.has(name):
		return PROCESSED_GOODS[name]
	return {}

func get_commodity(name: String) -> Dictionary:
	return get_crop(name)

func is_processed_good(name: String) -> bool:
	return PROCESSED_GOODS.has(name)

func get_pest(name: String) -> Dictionary:
	return PESTS.get(name, {})

func get_building(name: String) -> Dictionary:
	return BUILDINGS.get(name, {})

func get_tech(name: String) -> Dictionary:
	return TECH.get(name, {})

## Returns the EFFECTIVE hub data: base values plus any bonuses from owned buildings
## (Biyahero Trading Post, Grain Mill / Wholesale Depot, Seaport Terminal).
func get_market_hub(name: String) -> Dictionary:
	var base: Dictionary = MARKET_HUBS.get(name, {})
	if base.is_empty():
		return base
	var hub: Dictionary = base.duplicate()
	var bm: Node = get_node_or_null("/root/BuildingManager")
	if bm == null:
		return hub
	if name == "local_biyahero":
		hub["price_multiplier"] = float(hub.get("price_multiplier", 0.72)) + bm.get_biyahero_price_bonus()
		return hub
	var req: String = str(hub.get("requires_building", ""))
	if req != "" and bm.has_building(req):
		var perk: Dictionary = get_building(req)
		hub["price_multiplier"] = float(hub.get("price_multiplier", 1.0)) + float(perk.get("hub_price_bonus", 0.0))
		hub["rot_risk_percent"] = float(hub.get("rot_risk_percent", 0.0)) * (1.0 - float(perk.get("hub_rot_cut", 0.0)))
		hub["fuel_cost"] = int(round(float(hub.get("fuel_cost", 0)) * (1.0 - float(perk.get("hub_fuel_cut", 0.0)))))
		hub["boosted"] = true
	return hub

## False when a sell hub needs a building the player has not built yet.
func is_hub_available(name: String) -> bool:
	var req: String = str(MARKET_HUBS.get(name, {}).get("requires_building", ""))
	if req == "":
		return true
	var bm: Node = get_node_or_null("/root/BuildingManager")
	return bm != null and bm.has_building(req)

# ---------------------------------------------------------------------------
# Land Expansion Parcels (10x10 each)
# ---------------------------------------------------------------------------
const LAND_PARCELS: Array[Dictionary] = [
	{
		"id": "homestead",
		"name": "Central Homestead",
		"rect": Rect2i(0, 0, 12, 12),
		"cost": 0,
		"unlocked_by_default": true,
		"sign_tile": Vector2i(5, 5),
		"description": "Your starting farm estate. 12x12 cultivated area (144 plots).",
	},
	{
		"id": "east_meadows",
		"name": "Eastern Riverbanks",
		"rect": Rect2i(12, 0, 12, 12),
		"cost": 1500,
		"unlocked_by_default": false,
		"sign_tile": Vector2i(14, 2),
		"description": "Rich alluvial flatlands. Adds 12x12 (144 plots) eastward for rice paddies, buildings, and canals.",
	},
	{
		"id": "south_plains",
		"name": "Southern Lowlands",
		"rect": Rect2i(0, 12, 12, 12),
		"cost": 2400,
		"unlocked_by_default": false,
		"sign_tile": Vector2i(2, 14),
		"description": "Expansive flatlands. Adds 12x12 (144 plots) southward for crop rows, warehouses, and mills.",
	},
	{
		"id": "highland_plateau",
		"name": "Highland Foothills",
		"rect": Rect2i(12, 12, 12, 12),
		"cost": 4200,
		"unlocked_by_default": false,
		"sign_tile": Vector2i(14, 14),
		"description": "Elevated volcanic plateau. Adds 12x12 (144 plots) southeastward with shelter from low-elevation floods.",
	},
]

func get_parcel(id: String) -> Dictionary:
	for p in LAND_PARCELS:
		if p.get("id") == id:
			return p
	return {}

func get_parcel_for_tile(pos: Vector2i) -> Dictionary:
	for p in LAND_PARCELS:
		var r: Rect2i = p["rect"]
		if r.has_point(pos):
			return p
	return {}
