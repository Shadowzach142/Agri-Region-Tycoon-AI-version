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
		"water_min": 40,
		"water_max": 80,
		"heat_min": 20,
		"heat_max": 35,
		"base_price": 100,
		"pests": ["kuhol", "rice_black_bug"],
		"seed_cost": 25,
	},
	"yellow_corn": {
		"display_name": "Yellow Corn",
		"icon": "🌽",
		"growth_days": 45,
		"water_min": 45,
		"water_max": 85,
		"heat_min": 22,
		"heat_max": 38,
		"base_price": 120,
		"pests": ["armyworm"],
		"seed_cost": 30,
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
	},
}

# Pest definitions
const PESTS = {
	"kuhol": {
		"display_name": "Golden Apple Snail (Kuhol)",
		"spawn_trigger": {"soil_moisture_below": 30},
		"spread_rate": 0.2,  # chance per day
		"treatment_cost": 30,
	},
	"armyworm": {
		"display_name": "Fall Armyworm",
		"spawn_trigger": {"crop_density_above": 3},
		"spread_rate": 0.3,
		"treatment_cost": 40,
	},
	"rice_black_bug": {
		"display_name": "Rice Black Bug",
		"spawn_trigger": {"soil_moisture_above": 85},
		"spread_rate": 0.15,
		"treatment_cost": 35,
	},
	"fusarium_wilt": {
		"display_name": "Fusarium Wilt (Panama Disease)",
		"spawn_trigger": {"heat_index_above": 32},
		"spread_rate": 0.10,
		"treatment_cost": 60,
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
		"grid_size": Vector2i(2, 2),
		"cost": 200,
		"storage_limit": 0,
		"worker_capacity": 1,
	},
	"bodega": {
		"display_name": "Grain Bodega",
		"grid_size": Vector2i(3, 3),
		"cost": 500,
		"storage_limit": 1000,
		"halts_spoilage": false,
	},
	"cold_storage": {
		"display_name": "Cold Storage Facility",
		"grid_size": Vector2i(3, 3),
		"cost": 800,
		"storage_limit": 2000,
		"halts_spoilage": true,
	},
	"solar_dryer": {
		"display_name": "Solar Dryer (Bilaran)",
		"grid_size": Vector2i(2, 2),
		"cost": 300,
		"storage_limit": 0,
		"drying_bonus": 0.05,
	},
	"machine_garage": {
		"display_name": "Machine Garage",
		"grid_size": Vector2i(3, 2),
		"cost": 600,
		"storage_limit": 0,
		"unlocks_machines": true,
	},
	"climate_silo": {
		"display_name": "Climate-Controlled Silo",
		"grid_size": Vector2i(3, 3),
		"cost": 1200,
		"storage_limit": 5000,
		"halts_spoilage": true,
	},
}

# Tech definitions
const TECH = {
	"radio_tower": {
		"display_name": "AM Radio Tower (Tier 1)",
		"forecast_days": 1,
		"accuracy": 0.60,
		"cost": 300,
	},
	"aws_station": {
		"display_name": "Automated Weather Station (Tier 2)",
		"forecast_days": 3,
		"accuracy": 0.90,
		"cost": 750,
	},
	"iot_soil_sensor": {
		"display_name": "Satellite / IoT Sensor Net (Tier 3)",
		"forecast_days": 7,
		"accuracy": 1.00,
		"cost": 1500,
	},
	"kuliglig": {
		"display_name": "Kuliglig Hand-Tractor",
		"type": "machine",
		"work_speed_multiplier": 2.0,
		"cost": 800,
	},
	"combine_harvester": {
		"display_name": "Combine Harvester",
		"type": "machine",
		"work_speed_multiplier": 5.0,
		"cost": 3000,
	},
	"drip_irrigation": {
		"display_name": "Sensor-Linked Drip Irrigation",
		"type": "automation",
		"auto_water": true,
		"cost": 1500,
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
