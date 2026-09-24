# Data.gd
# Autoload singleton containing static game data dictionaries

extends Node

# Current selected region (set by MainMenu)
var current_region: String = "cotabato"

# Regions with default soil moisture (0-100) and hazard probabilities (0-1)
const REGIONS = {
	"cotabato": {
		"display_name": "Cotabato Basin (Central Floodplains)",
		"soil_moisture": 65,
		"specialty": "Rice Paddies & Wetland Agriculture",
		"description": "The fertile rice bowl of Central Mindanao, fed by the Pulangi and Rio Grande de Mindanao river systems. Features naturally rich alluvial soils ideal for continuous rice cultivation.",
		"pros": [
			"High natural soil moisture (65%) and excellent soil fertility",
			"Accelerated Palay (Rice) growth and bumper harvest yields",
			"Low risk of severe drought during typical seasons"
		],
		"cons": [
			"Severe vulnerability to La Niña flash floods and prolonged river overflow",
			"High risk of Golden Apple Snail (Kuhol) infestations in wet paddies",
			"Prolonged over-saturation (>90% moisture) triggers destructive crop rot"
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
		"specialty": "Highland Specialty Crops & Volcanic Plateaus",
		"description": "Cool volcanic slopes and upland plateaus surrounding Mount Matutum and Lake Sebu. Renowned for premium Arabica Coffee and high-grade Yellow Corn.",
		"pros": [
			"Temperate upland climate prevents heat stress and yields Grade A produce",
			"Volcanic soil gives +20% market value on Arabica Coffee & Corn",
			"Naturally sheltered from low-elevation flash floods"
		],
		"cons": [
			"Steep slope gradients carry significant Landslide risks during rainstorms",
			"High vulnerability to Fusarium Wilt (Panama Disease)",
			"Increased transportation and logistics costs through mountain roads"
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
		"description": "Sun-drenched agrarian coastal plains along Sarangani Bay and the Celebes Sea. Suited for drought-hardy Coconut Palms, Cavendish Bananas, and deep-sea export trade.",
		"pros": [
			"Ideal tropical climate for hardy Coconut Palm & Banana plantations",
			"Direct proximity to coastal shipping routes and low freight costs",
			"Minimal risk of landslides or catastrophic river inundation"
		],
		"cons": [
			"Acute susceptibility to severe El Niño droughts and blistering heatwaves",
			"Low baseline soil moisture (45%) requiring frequent irrigation",
			"High risk of Fall Armyworm outbreaks during prolonged dry spells"
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
		"specialty": "Large-Scale Mechanization & Crop Rotation",
		"description": "Expansive flatlands and open agricultural corridors perfect for tractor mechanization, multi-crop rotation, and commercial grain production.",
		"pros": [
			"Broad flat terrain maximizes efficiency for Kuliglig tractors & harvesters",
			"Balanced soil conditions suitable for rotating Palay, Corn, and Legumes",
			"Substantial grain volume output and cheaper infrastructure layout"
		],
		"cons": [
			"Significant fuel expenses and maintenance demands for agricultural machinery",
			"Monoculture density accelerates Fall Armyworm and Rice Black Bug spread",
			"Dumping huge harvest volumes depresses local market prices"
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
		"description": "The trade capital and logistics gateway of Region 12. Offers direct seaport international shipping, industrial cold chain facilities, and export packaging.",
		"pros": [
			"Direct access to the GenSan Export Seaport with maximum market rates (+35%)",
			"Industrial Cold Storage halts spoilage and safeguards harvest value",
			"Rapid supply chain access to high-tier weather stations and IPM treatments"
		],
		"cons": [
			"Higher baseline worker payroll wages and urban property costs",
			"Urban heat island effect and humid coastal pockets favor Fusarium Wilt",
			"Substantial seaport inspection and freight handling surcharges"
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
		"growth_days": 30,
		"water_min": 70,
		"water_max": 90,
		"heat_min": 20,
		"heat_max": 35,
		"base_price": 100,
		"pests": ["kuhol", "rice_black_bug"],
		"seed_cost": 25,
		"description": "Thrives in wetland paddies (70-90% moisture). Halts growth if moisture < 30%. Waterlogging (>95% for 12+ hrs) causes destructive rot!",
	},
	"yellow_corn": {
		"display_name": "Yellow Corn",
		"icon": "🌽",
		"growth_days": 45,
		"water_min": 30,
		"water_max": 60,
		"heat_min": 22,
		"heat_max": 45,
		"base_price": 120,
		"pests": ["armyworm"],
		"seed_cost": 30,
		"description": "Hardy cereal crop requiring moderate moisture (30-60%). Resilient against extreme heat up to 45°C.",
	},
	"arabica_coffee": {
		"display_name": "Arabica Coffee",
		"icon": "☕",
		"growth_days": 60,
		"water_min": 35,
		"water_max": 70,
		"heat_min": 18,
		"heat_max": 30,
		"base_price": 200,
		"pests": ["kuhol", "fusarium_wilt"],
		"seed_cost": 50,
		"description": "High-margin specialty crop with long 60-day maturation. Extremely sensitive to flooding—paddy floods permanently kill coffee trees!",
	},
	"banana": {
		"display_name": "Cavendish Banana",
		"icon": "🍌",
		"growth_days": 120,
		"water_min": 55,
		"water_max": 85,
		"heat_min": 24,
		"heat_max": 36,
		"base_price": 90,
		"pests": ["fusarium_wilt"],
		"seed_cost": 35,
		"description": "Tropical export perennial. Vulnerable to fungal Fusarium Wilt (Panama Disease) in high humidity.",
	},
	"coconut": {
		"display_name": "Coconut Palm",
		"icon": "🥥",
		"growth_days": 365,
		"water_min": 40,
		"water_max": 75,
		"heat_min": 20,
		"heat_max": 38,
		"base_price": 80,
		"pests": ["armyworm"],
		"seed_cost": 40,
		"description": "Drought-hardy perennial crop suited for coastal soils. Longest lifecycle with consistent yields.",
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
		"description": "Regional bulk grain processor. 45 km transit, ₱45 fuel cost, minor road spoilage (10% decay).",
	},
	"koronadal": {
		"display_name": "Koronadal City Wholesale Market",
		"distance_km": 68,
		"travel_days": 1,
		"fuel_cost": 75,
		"price_multiplier": 1.20,
		"rot_risk_percent": 18.0,
		"description": "Provincial commercial hub. 68 km transit, ₱75 fuel, moderate road rot risk (18% decay).",
	},
	"gensan_port": {
		"display_name": "General Santos Export Seaport",
		"distance_km": 135,
		"travel_days": 2,
		"fuel_cost": 160,
		"price_multiplier": 1.55,
		"rot_risk_percent": 35.0,
		"description": "High-payout international export gateway. 135 km trip, ₱160 fuel, severe road rot risk (35% decay) unless preserved in Cold Storage!",
	},
}

# Building definitions
const BUILDINGS = {
	"bahay_kubo": {
		"display_name": "Bahay Kubo (Farm Shack)",
		"icon": "🏠",
		"grid_size": Vector2i(2, 2),
		"cost": 200,
		"build_time": 15.0,
		"max_level": 3,
		"storage_limit": 0,
		"worker_capacity": 1,
		"description": "Expands farm housing by +1 worker capacity, allowing you to hire more autonomous farm laborers.",
	},
	"bodega": {
		"display_name": "Grain Bodega",
		"icon": "🏛️",
		"grid_size": Vector2i(3, 3),
		"cost": 500,
		"build_time": 25.0,
		"max_level": 3,
		"storage_limit": 1000,
		"halts_spoilage": false,
		"description": "Basic warehouse providing 1,000 units of crop storage. Produce in basic bodega spoils at 5% freshness per hour.",
	},
	"cold_storage": {
		"display_name": "Cold Storage Facility",
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
		"icon": "☀️",
		"grid_size": Vector2i(2, 2),
		"cost": 300,
		"build_time": 20.0,
		"max_level": 3,
		"storage_limit": 0,
		"drying_bonus": 0.25,
		"description": "Traditional concrete sun-drying pavement. Boosts harvested grain quality and market selling value by +25%!",
	},
	"machine_garage": {
		"display_name": "Machine Garage",
		"icon": "🚜",
		"grid_size": Vector2i(3, 2),
		"cost": 600,
		"build_time": 30.0,
		"max_level": 3,
		"storage_limit": 0,
		"unlocks_machines": true,
		"description": "Mechanized maintenance depot required for parking heavy tractors and combine harvesters.",
	},
	"climate_silo": {
		"display_name": "Climate-Controlled Silo",
		"icon": "🗼",
		"grid_size": Vector2i(3, 3),
		"cost": 1200,
		"build_time": 45.0,
		"max_level": 3,
		"storage_limit": 5000,
		"halts_spoilage": true,
		"description": "High-tech airtight grain silo with 5,000 storage capacity. Eliminates moisture rot and maintains 100% grain freshness.",
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
	"kuliglig": {
		"display_name": "Kuliglig Hand-Tractor",
		"type": "machine",
		"work_speed_multiplier": 2.0,
		"cost": 800,
		"description": "Motorized two-wheel hand tractor. Multiplies worker travel and plowing speed by 2x.",
	},
	"combine_harvester": {
		"display_name": "Combine Harvester",
		"type": "machine",
		"work_speed_multiplier": 5.0,
		"cost": 3000,
		"description": "Heavy industrial harvesting machine. Speeds up crop harvesting and processing by 5x.",
	},
	"drip_irrigation": {
		"display_name": "Sensor-Linked Drip Irrigation",
		"type": "automation",
		"auto_water": true,
		"cost": 1500,
		"description": "Automated moisture regulation that automatically irrigates thirsty planted tiles every hour.",
	},
}

func get_region(name: String) -> Dictionary:
	return REGIONS.get(name, REGIONS["cotabato"])

func get_crop(name: String) -> Dictionary:
	return CROPS.get(name, {})

func get_pest(name: String) -> Dictionary:
	return PESTS.get(name, {})

func get_building(name: String) -> Dictionary:
	return BUILDINGS.get(name, {})

func get_tech(name: String) -> Dictionary:
	return TECH.get(name, {})

func get_market_hub(name: String) -> Dictionary:
	return MARKET_HUBS.get(name, {})
