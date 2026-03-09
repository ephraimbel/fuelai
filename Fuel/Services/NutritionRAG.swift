import Foundation

final class NutritionRAG: @unchecked Sendable {
    static let shared = NutritionRAG()
    private let database = FoodDatabase.shared
    private let _lock = NSLock()
    private init() {}

    // MARK: - Pre-built Index (built once, invalidated on DB change)

    private var _index: FoodIndex?
    private var _isBuilding = false

    /// The combined food list the current index was built from.
    /// Must stay in sync with the index so candidate indices are valid.
    private var _indexedFoods: [FoodItem] = []

    /// Returns the current index and its matching foods array atomically.
    /// Non-blocking poll loop replaces the old recursive Thread.sleep that froze MainActor.
    private func indexAndFoods() -> (FoodIndex, [FoodItem]) {
        _lock.lock()
        // Return cached if available
        if let cached = _index {
            let foods = _indexedFoods
            _lock.unlock()
            return (cached, foods)
        }
        // If another thread is already building, poll until it finishes
        if _isBuilding {
            _lock.unlock()
            // Non-blocking poll: check every 10ms, give up after ~2 seconds
            for i in 0..<200 {
                _lock.lock()
                if let cached = _index {
                    let foods = _indexedFoods
                    _lock.unlock()
                    return (cached, foods)
                }
                let stillBuilding = _isBuilding
                _lock.unlock()
                if !stillBuilding { break } // Builder finished but index wasn't set — fall through to build
                if i % 5 == 0 {
                    Thread.sleep(forTimeInterval: 0.01) // 10ms
                } else {
                    usleep(1000) // 1ms micro-sleep
                }
            }
            // Timed out or builder cleared — fall through and build our own
        }
        _isBuilding = true
        _lock.unlock()

        // Build index WITHOUT holding lock (avoids deadlock with FoodAPICache barrier)
        let allFoods = database.foods + FoodAPICache.shared.allFoods
        let built = FoodIndex(foods: allFoods, normalize: normalize, synonyms: synonyms)

        _lock.lock()
        _indexedFoods = allFoods
        _index = built
        _isBuilding = false
        _lock.unlock()
        return (built, allFoods)
    }

    private var index: FoodIndex {
        indexAndFoods().0
    }

    /// Reset all caches. Call after the food database has been modified (e.g. remote merge).
    func invalidateCache() {
        _lock.lock()
        defer { _lock.unlock() }
        _index = nil
        _indexedFoods = []
        _isBuilding = false
    }

    // MARK: - Compound Foods

    private let compoundFoods: [String] = [
        // Classic combos
        "macaroni and cheese", "mac and cheese", "peanut butter and jelly",
        "rice and beans", "fish and chips", "chips and salsa", "chips and guac",
        "chips and guacamole", "bread and butter", "salt and pepper",
        "franks and beans", "biscuits and gravy", "chicken and waffles",
        "chicken and dumplings", "shrimp and grits", "steak and eggs",
        "bacon and eggs", "ham and cheese", "meat and potatoes",
        "pork and beans", "surf and turf", "lox and bagel",
        "milk and cereal", "cookies and cream", "peaches and cream",
        "strawberries and cream", "spaghetti and meatballs", "burger and fries",
        "pizza and wings", "rice and peas", "beans and rice", "red beans and rice",
        "egg and cheese", "bagel and cream cheese",
        "toast and jam", "toast and butter", "cereal and milk",
        "hummus and pita", "chips and dip", "meat and cheese",
        "peanut butter and banana", "bacon and cheese",
        // Breakfast combos
        "eggs and toast", "eggs and bacon", "eggs and sausage",
        "pancakes and syrup", "waffles and syrup", "oatmeal and fruit",
        "yogurt and granola", "bagel and lox", "cream cheese and bagel",
        "hash browns and eggs", "grits and butter", "french toast and syrup",
        // Dinner combos
        "steak and potatoes", "chicken and rice", "salmon and rice",
        "pork and rice", "lamb and rice", "fish and rice",
        "chicken and vegetables", "steak and broccoli", "chicken and broccoli",
        "meatballs and sauce", "rice and curry", "naan and curry",
        "bread and soup", "salad and soup", "soup and sandwich",
        "chips and queso", "wings and fries", "tenders and fries",
        // International combos
        "injera and wot", "rice and dal", "rice and beans",
        "tortilla and beans", "pita and hummus", "naan and tikka masala",
        "rice and stir fry", "noodles and broth", "rice and kimchi",
        "miso and rice", "tempura and rice", "sushi and miso",
        // Snack combos
        "crackers and cheese", "apples and peanut butter", "celery and peanut butter",
        "pretzels and cheese", "fruit and yogurt", "granola and milk",
        "trail mix and fruit", "veggies and dip", "veggies and hummus",
    ]

    // MARK: - Synonyms

    private let synonyms: [String: [String]] = [
        // Beverages
        "soda": ["pop", "soft drink", "cola", "coke", "fizzy drink"],
        "pop": ["soda", "soft drink", "cola"],
        "coke": ["coca cola", "soda", "cola"],
        "pepsi": ["cola", "soda"],
        "juice": ["jugo", "jus"],
        "coffee": ["cafe", "java", "joe", "brew", "kopi", "kahve", "kaffe"],
        "latte": ["cafe latte", "caffe latte", "cafe con leche"],
        "espresso": ["cafe espresso", "shot"],
        "tea": ["chai", "cha", "te"],
        "smoothie": ["shake", "blended drink"],
        "milkshake": ["shake", "malt", "frappe"],
        "beer": ["brew", "ale", "lager", "cerveza", "bier", "biere"],
        "wine": ["vino", "vin"],
        "cocktail": ["mixed drink"],
        "water": ["agua", "eau"],
        "boba": ["bubble tea", "pearl milk tea", "tapioca tea"],
        // Sandwich types
        "sub": ["hoagie", "hero", "grinder", "submarine", "po boy"],
        "grinder": ["sub", "hoagie", "hero"],
        "hoagie": ["sub", "hero", "grinder"],
        "wrap": ["tortilla wrap", "burrito"],
        "panini": ["pressed sandwich", "grilled sandwich"],
        "flatbread": ["naan", "pita", "lavash"],
        // Proteins
        "chicken": ["pollo", "poulet", "huhn", "tori", "dak"],
        "beef": ["carne", "boeuf", "rind", "gyu"],
        "pork": ["cerdo", "puerco", "porc", "schwein", "buta"],
        "fish": ["pescado", "poisson", "sakana", "pesce"],
        "shrimp": ["prawns", "gambas", "camarones", "ebi"],
        "prawns": ["shrimp", "gambas", "camarones"],
        "turkey": ["pavo"],
        "lamb": ["cordero", "agneau", "mutton"],
        "steak": ["bistec", "filete", "beefsteak"],
        "bacon": ["pancetta", "tocino", "lardons"],
        "sausage": ["salchicha", "chorizo", "wurst", "kielbasa"],
        "tofu": ["doufu", "bean curd", "tahu"],
        "tempeh": ["tempe"],
        // Dairy
        "cheese": ["queso", "fromage", "formaggio", "kase"],
        "yogurt": ["yoghurt", "yoghourt", "curd"],
        "milk": ["leche", "lait", "milch"],
        "butter": ["mantequilla", "beurre"],
        "cream": ["crema", "creme", "sahne"],
        "ice cream": ["helado", "gelato", "glace"],
        // Grains & Starches
        "rice": ["arroz", "riz", "reis", "gohan", "chawal", "bap", "nasi"],
        "bread": ["pan", "pain", "brot", "roti", "naan", "pane"],
        "pasta": ["noodles", "fideos", "nudeln"],
        "noodles": ["pasta", "mian", "men", "myeon", "mee", "noodle"],
        "tortilla": ["wrap"],
        "fries": ["chips", "french fries", "freedom fries", "papas fritas", "pommes frites", "pommes"],
        "chips": ["crisps"],
        "oatmeal": ["porridge", "oats", "avena"],
        "cereal": ["breakfast cereal"],
        "pancakes": ["hotcakes", "flapjacks", "griddle cakes"],
        "waffle": ["waffles", "gaufre"],
        // Fruits
        "banana": ["platano", "banane"],
        "apple": ["manzana", "pomme", "apfel"],
        "orange": ["naranja", "naranje"],
        "mango": ["mangue"],
        "pineapple": ["pina", "ananas"],
        "strawberry": ["fresa", "fraise", "erdbeere"],
        "blueberry": ["arandano"],
        "avocado": ["aguacate", "avo"],
        "grapes": ["uvas", "raisins"],
        "watermelon": ["sandia", "pasteque"],
        "coconut": ["coco"],
        // Vegetables
        "potato": ["papa", "patata", "pomme de terre", "kartoffel"],
        "tomato": ["tomate", "pomodoro"],
        "onion": ["cebolla", "oignon", "cipolla", "zwiebel"],
        "corn": ["maiz", "elote", "mais"],
        "broccoli": ["brocoli"],
        "spinach": ["espinaca", "epinard"],
        "lettuce": ["lechuga", "laitue"],
        "pepper": ["pimiento", "poivron"],
        "mushroom": ["champiñon", "hongo", "champignon", "pilz"],
        "cabbage": ["col", "repollo", "chou"],
        "carrot": ["zanahoria", "carotte"],
        "beans": ["frijoles", "haricots", "bohnen", "judias"],
        "lentils": ["lentejas", "lentilles", "dal", "daal"],
        "chickpeas": ["garbanzo", "garbanzos", "chole", "chana"],
        // Condiments & Sauces
        "ketchup": ["catsup", "tomato sauce"],
        "mayo": ["mayonnaise", "mayonesa"],
        "mustard": ["mostaza", "moutarde", "senf"],
        "soy sauce": ["shoyu", "soya sauce", "tamari"],
        "hot sauce": ["salsa picante", "chili sauce", "sriracha"],
        "salsa": ["pico de gallo", "salsa fresca"],
        "guacamole": ["guac"],
        "hummus": ["houmous", "humus"],
        // Cooking terms
        "fried": ["deep fried", "pan fried", "frito"],
        "grilled": ["chargrilled", "barbecued", "a la parrilla", "asado"],
        "baked": ["al horno", "horneado"],
        "steamed": ["al vapor"],
        "roasted": ["asado", "rostizado"],
        "raw": ["crudo", "cru"],
        // Fast food brand synonyms
        "mcdonalds": ["mcd", "maccas", "mickey ds", "golden arches"],
        "burger king": ["bk"],
        "wendys": ["wendy"],
        "taco bell": ["tb", "tacobell", "tbell"],
        "chick fil a": ["cfa", "chickfila", "chik fil a", "chic fil a"],
        "chipotle": ["chipotles"],
        "subway": ["subs"],
        "starbucks": ["sbux", "starbs", "starbies"],
        "dunkin": ["dunkin donuts", "dunkindonuts", "dd"],
        "popeyes": ["popeye", "popeyes chicken"],
        "panda express": ["panda", "pandaexpress"],
        "five guys": ["5 guys", "fiveguys"],
        "in n out": ["innout", "in and out"],
        // Dish types
        "burrito": ["wrap", "burrito bowl"],
        "taco": ["taco shell", "street taco"],
        "pizza": ["za", "pie", "flatbread pizza"],
        "burger": ["hamburger", "cheeseburger"],
        "sandwich": ["sammy", "sammie", "sando", "butty"],
        "soup": ["sopa", "soupe", "suppe", "potage", "stew", "broth"],
        "salad": ["ensalada", "salade", "insalata"],
        "sushi": ["maki", "nigiri", "sashimi", "roll"],
        "ramen": ["ramyeon", "lamian"],
        "pho": ["vietnamese soup"],
        "curry": ["kari", "cari"],
        "stir fry": ["wok", "chao"],
        "dim sum": ["yum cha", "dian xin"],
        "dumplings": ["jiaozi", "gyoza", "mandu", "momo", "pierogi"],
        "kebab": ["kabob", "kabab", "skewer", "shish"],
        // Desserts
        "donut": ["doughnut", "dona"],
        "doughnut": ["donut"],
        "cake": ["gateau", "torte", "pastel", "kuchen"],
        "cookie": ["biscuit", "galleta"],
        "pie": ["tart", "pastel"],
        "brownie": ["chocolate brownie", "fudge brownie"],
        "mochi": ["mochi ice cream", "daifuku"],
        // Common abbreviations/slang
        "bbq": ["barbecue", "barbeque", "bbq sauce"],
        "barbecue": ["bbq", "barbeque"],
        "veggies": ["vegetables", "veg"],
        "oj": ["orange juice"],
        "pb": ["peanut butter"],
        "evoo": ["olive oil", "extra virgin olive oil"],
        "chx": ["chicken"],
        "chkn": ["chicken"],
        "grd": ["ground"],
        "brst": ["breast"],
        "sw": ["sandwich"],
        "burg": ["burger", "hamburger"],
        "nugs": ["nuggets", "chicken nuggets"],
        "tots": ["tater tots"],
        "avo": ["avocado"],
        "broc": ["broccoli"],
        "parm": ["parmesan"],
        "mac": ["macaroni"],
        "choc": ["chocolate"],
        "straw": ["strawberry"],
        "blue": ["blueberry"],
        "cran": ["cranberry"],
        "pep": ["pepper", "pepperoni"],
        "mush": ["mushroom"],
        "tom": ["tomato"],
        "zuke": ["zucchini"],
        "cauli": ["cauliflower"],
        "sweet pot": ["sweet potato"],
        "seltzer": ["sparkling water", "club soda", "mineral water"],
        // Meal type synonyms
        "entree": ["main course", "main dish"],
        "appetizer": ["starter", "app", "appy"],
        "side": ["side dish", "accompaniment"],
        "snack": ["munchie", "nosh", "bite"],
    ]

    // MARK: - Meal Combo Decomposition

    /// Known meal combos that should be decomposed into individual items for search.
    /// Maps a combo name to its component items.
    private let mealCombos: [String: [String]] = [
        // McDonald's
        "big mac meal": ["big mac", "medium french fries", "medium coke"],
        "mcdonalds meal": ["big mac", "medium french fries", "medium coke"],
        "quarter pounder meal": ["quarter pounder with cheese", "medium french fries", "medium coke"],
        "mcnugget meal": ["chicken mcnuggets 10pc", "medium french fries", "medium coke"],
        "mcnuggets meal": ["chicken mcnuggets 10pc", "medium french fries", "medium coke"],
        "egg mcmuffin meal": ["egg mcmuffin", "hash brown", "small coffee"],
        "mcdouble meal": ["mcdouble", "medium french fries", "medium coke"],
        "mcchicken meal": ["mcchicken", "medium french fries", "medium coke"],
        "filet o fish meal": ["filet o fish", "medium french fries", "medium coke"],
        "happy meal": ["small cheeseburger", "small french fries", "apple slices", "small milk"],
        "mcgriddle meal": ["sausage mcgriddle", "hash brown", "small coffee"],
        "sausage mcmuffin meal": ["sausage mcmuffin with egg", "hash brown", "small coffee"],
        // Burger King
        "whopper meal": ["whopper", "medium french fries", "medium coke"],
        "whopper jr meal": ["whopper jr", "small french fries", "small coke"],
        "double whopper meal": ["double whopper", "medium french fries", "medium coke"],
        // Chick-fil-A
        "chick fil a meal": ["chick fil a sandwich", "medium waffle fries", "medium lemonade"],
        "cfa meal": ["chick fil a sandwich", "medium waffle fries", "medium lemonade"],
        "chick fil a nugget meal": ["chick fil a nuggets 12ct", "medium waffle fries", "medium lemonade"],
        "spicy deluxe meal": ["chick fil a spicy deluxe", "medium waffle fries", "medium lemonade"],
        "chick fil a spicy meal": ["chick fil a spicy sandwich", "medium waffle fries", "medium lemonade"],
        "chick fil a breakfast": ["chick fil a chicken biscuit", "hash browns", "small coffee"],
        // Taco Bell
        "taco bell combo": ["crunchy taco", "burrito supreme", "medium baja blast"],
        "crunchwrap combo": ["crunchwrap supreme", "crunchy taco", "medium baja blast"],
        "taco bell box": ["crunchy taco", "burrito supreme", "cinnamon twists", "medium baja blast"],
        "chalupa combo": ["chalupa supreme", "crunchy taco", "medium baja blast"],
        // Wendy's
        "wendys combo": ["wendys daves single", "medium french fries", "medium coke"],
        "baconator meal": ["baconator", "medium french fries", "medium coke"],
        "daves double meal": ["wendys daves double", "medium french fries", "medium coke"],
        "spicy chicken meal": ["wendys spicy chicken", "medium french fries", "medium coke"],
        // Chipotle
        "chipotle bowl": ["cilantro lime rice", "black beans", "chicken", "fajita veggies", "salsa", "sour cream", "cheese"],
        "chipotle burrito": ["flour tortilla", "cilantro lime rice", "black beans", "chicken", "salsa", "sour cream", "cheese"],
        "chipotle steak bowl": ["cilantro lime rice", "black beans", "steak", "fajita veggies", "salsa", "guacamole"],
        "chipotle chicken bowl": ["cilantro lime rice", "black beans", "chicken", "corn salsa", "cheese", "lettuce"],
        // Subway
        "subway footlong meal": ["12 inch sub", "chips", "medium soda"],
        "subway 6 inch meal": ["6 inch sub", "chips", "small soda"],
        // Five Guys
        "five guys meal": ["five guys cheeseburger", "cajun fries", "medium soda"],
        "five guys burger and fries": ["five guys cheeseburger", "regular fries"],
        // Popeyes
        "popeyes meal": ["popeyes chicken sandwich", "cajun fries", "medium soda"],
        "popeyes 2pc meal": ["2pc popeyes chicken", "red beans and rice", "biscuit"],
        "popeyes 3pc meal": ["3pc popeyes chicken", "cajun fries", "biscuit", "medium soda"],
        // Panda Express
        "panda express plate": ["fried rice", "orange chicken", "beijing beef"],
        "panda express bowl": ["fried rice", "orange chicken"],
        "panda express bigger plate": ["chow mein", "orange chicken", "beijing beef", "kung pao chicken"],
        // Raising Cane's
        "canes combo": ["3 chicken fingers", "crinkle cut fries", "coleslaw", "canes sauce", "texas toast"],
        "canes box combo": ["4 chicken fingers", "crinkle cut fries", "coleslaw", "canes sauce", "texas toast", "medium soda"],
        // Starbucks
        "starbucks breakfast": ["grande latte", "breakfast sandwich"],
        "starbucks lunch": ["grande coffee", "turkey sandwich", "madeleines"],
        // Dunkin
        "dunkin breakfast": ["medium iced coffee", "bacon egg cheese bagel"],
        "dunkin combo": ["medium coffee", "glazed donut"],
        // In-N-Out
        "in n out meal": ["double double", "french fries", "medium soda"],
        "in n out double double meal": ["double double", "french fries", "medium shake"],
        // Wingstop
        "wingstop meal": ["10 bone in wings", "cajun corn", "ranch"],
        // Shake Shack
        "shake shack meal": ["shackburger", "crinkle cut fries", "shake"],
        // KFC
        "kfc meal": ["2pc kfc chicken", "mashed potatoes with gravy", "coleslaw", "biscuit"],
        "kfc bucket": ["8pc kfc chicken", "mashed potatoes with gravy", "coleslaw", "4 biscuits"],
        // Generic meals
        "combo meal": ["burger", "medium french fries", "medium soda"],
        "value meal": ["burger", "small french fries", "small soda"],
        "breakfast combo": ["2 eggs", "2 bacon strips", "toast"],
        "grand slam": ["2 eggs", "2 bacon strips", "2 pancakes", "hash browns"],
        "steak dinner": ["8oz steak", "baked potato", "side salad"],
        "fish and chips": ["fried fish", "french fries"],
        "chicken dinner": ["grilled chicken breast", "mashed potatoes", "steamed broccoli"],
        "salmon dinner": ["grilled salmon fillet", "rice", "steamed vegetables"],
        "pasta dinner": ["spaghetti with marinara", "garlic bread", "side salad"],
        "bbq plate": ["pulled pork", "coleslaw", "cornbread", "baked beans"],
        "wing night": ["12 buffalo wings", "celery sticks", "ranch dressing"],
        "taco plate": ["3 tacos", "rice", "beans"],
        "sushi combo": ["8pc california roll", "4pc spicy tuna roll", "miso soup", "edamame"],
        "dim sum": ["3 har gow", "3 siu mai", "2 char siu bao", "fried rice"],
        // Coffee combos
        "coffee and pastry": ["medium coffee with cream", "croissant"],
        "coffee and donut": ["medium coffee", "glazed donut"],
        // Breakfast plates
        "eggs benedict meal": ["eggs benedict", "hash browns", "fruit cup"],
        "french toast plate": ["3 french toast slices", "2 bacon strips", "maple syrup"],
        "pancake breakfast": ["3 pancakes", "2 eggs", "2 bacon strips", "maple syrup"],
        "waffle breakfast": ["2 waffles", "2 eggs", "2 sausage links", "maple syrup"],
        "omelette plate": ["3 egg omelette", "hash browns", "toast"],
        "acai bowl meal": ["acai bowl", "granola", "mixed berries"],
    ]

    // MARK: - Cooking Method Adjustments

    private let cookingMethodHints: [String: String] = [
        "fried": "Frying typically adds 50-150 cal from oil absorption.",
        "deep fried": "Deep frying adds 100-200 cal. Breaded items absorb more oil.",
        "grilled": "Grilling adds minimal calories (0-20 cal from oil brush).",
        "baked": "Baking adds minimal calories unless butter/oil is used.",
        "steamed": "Steaming adds zero calories. Lightest cooking method.",
        "sauteed": "Sautéing in oil/butter adds 40-120 cal per tablespoon of fat.",
        "pan fried": "Pan frying adds 50-100 cal from oil.",
        "broiled": "Broiling is similar to grilling, minimal added calories.",
        "roasted": "Roasting with oil adds 30-60 cal. Dry roast adds nothing.",
        "smoked": "Smoking adds negligible calories.",
        "air fried": "Air frying uses minimal oil, adds 0-20 cal.",
        "blackened": "Blackening spice rub adds ~10 cal. Usually pan-seared in butter (50+ cal).",
        "braised": "Braising liquid adds 20-50 cal depending on sauce.",
        "poached": "Poaching adds zero calories.",
        "raw": "Raw/uncooked, no added calories from cooking.",
        "boiled": "Boiling adds zero calories.",
        "stewed": "Stewing adds 20-60 cal from broth/sauce. Vegetables absorb flavors.",
        "blanched": "Blanching adds zero calories. Brief boil preserves color/texture.",
        "caramelized": "Caramelizing may use butter/oil, adding 30-80 cal.",
        "glazed": "Glazing adds 50-150 cal from sugar/honey/butter glaze.",
        "stuffed": "Stuffing adds 100-300+ cal depending on filling (breadcrumb, cheese, etc).",
        "breaded": "Breading adds 50-100 cal from flour/egg/breadcrumbs before frying.",
        "tempura": "Tempura batter + deep frying adds 150-250 cal.",
        "teriyaki": "Teriyaki glaze adds 40-80 cal from sugar/soy.",
        "buffalo": "Buffalo sauce adds 15-30 cal. Often served with blue cheese/ranch (100+ cal extra).",
        "bbq": "BBQ sauce adds 30-70 cal per serving from sugar.",
        "alfredo": "Alfredo cream sauce adds 150-300 cal from cream/butter/parmesan.",
        "carbonara": "Carbonara adds 200-350 cal from egg yolk/pancetta/parmesan/cream.",
        "pesto": "Pesto adds 80-150 cal per serving from olive oil/pine nuts/parmesan.",
        "au gratin": "Au gratin adds 100-200 cal from cheese/cream topping.",
        "loaded": "Loaded typically adds 150-350 cal from cheese/bacon/sour cream/butter.",
        "smothered": "Smothered adds 100-250 cal from gravy/cheese/sauce.",
        "crispy": "Crispy usually means fried. Adds 50-150 cal from oil.",
        "crunchy": "Crunchy coating adds 50-100 cal. Usually fried or baked with oil.",
        "marinated": "Marinade itself adds 10-40 cal. Oil-based marinades add more.",
    ]

    // MARK: - Public API

    func retrieve(query: String, topK: Int = 15) -> [RetrievalResult] {
        // Step 0: Correct common misspellings before anything else
        let correctedQuery = correctSpelling(query)
        let normalizedQuery = normalize(correctedQuery)
        let rawTokens = tokenize(normalizedQuery)
        let queryTokens = expandWithSynonyms(rawTokens)

        // Detect multi-item queries and split into sub-queries
        let subQueries = splitMultiItemQuery(normalizedQuery)
        let isMultiItem = subQueries.count > 1

        // Use inverted index to narrow candidate set instead of scanning all foods
        let (idx, foods) = indexAndFoods()
        let candidateIndices: Set<Int>

        if isMultiItem {
            var all = Set<Int>()
            for sub in subQueries {
                let subTokens = expandWithSynonyms(tokenize(sub))
                all.formUnion(idx.candidates(for: subTokens, query: sub))
            }
            candidateIndices = all
        } else {
            candidateIndices = idx.candidates(for: queryTokens, query: normalizedQuery)
        }

        // Personal frequency boost: load user's meal history for scoring bonus
        let frequentMeals = MealHistoryService.shared.topMeals(limit: 50)
        let frequencyMap: [String: Int] = Dictionary(
            frequentMeals.map { ($0.name.lowercased(), $0.count) },
            uniquingKeysWith: { first, _ in first }
        )

        var results: [RetrievalResult] = []

        for i in candidateIndices where i < foods.count && i < idx.entries.count {
            let food = foods[i]
            let cached = idx.entries[i]

            if isMultiItem {
                var bestScore: Double = 0
                var bestTerms: [String] = []
                for sub in subQueries {
                    let subTokens = expandWithSynonyms(tokenize(sub))
                    let (score, terms) = scoreFood(cached, food: food, query: sub, queryTokens: subTokens, rawTokenCount: tokenize(sub).count)
                    if score > bestScore {
                        bestScore = score
                        bestTerms = terms
                    }
                }
                if bestScore > 0 {
                    bestScore = applyFrequencyBoost(bestScore, food: food, frequencyMap: frequencyMap)
                    results.append(RetrievalResult(food: food, score: bestScore, matchedTerms: bestTerms))
                }
            } else {
                var (score, matchedTerms) = scoreFood(cached, food: food, query: normalizedQuery, queryTokens: queryTokens, rawTokenCount: rawTokens.count)
                if score > 0 {
                    score = applyFrequencyBoost(score, food: food, frequencyMap: frequencyMap)
                    // Negative modifier penalty: penalize mismatched cooking methods
                    score = applyNegativeModifierPenalty(score, query: normalizedQuery, food: food)
                    results.append(RetrievalResult(food: food, score: score, matchedTerms: matchedTerms))
                }
            }
        }

        results.sort { $0.score > $1.score }

        // Apply minimum score threshold to filter noise
        let minScore: Double = 1.5
        let filtered = results.filter { $0.score >= minScore }

        return Array(filtered.prefix(topK))
    }

    func buildContext(from results: [RetrievalResult]) -> String {
        guard !results.isEmpty else { return "No matching foods found in database. Use your general nutritional knowledge and flag lower confidence." }

        // Smart filtering: only include results that are actually useful
        // 1. Always include results scoring >= 8.0 (strong matches)
        // 2. Include results >= 3.0 only if within 50% of top score (avoid noise)
        // 3. Cap at 10 results to keep context focused but comprehensive
        let topScore = results.first?.score ?? 0
        let relevant = results.filter { result in
            if result.score >= 8.0 { return true }
            if result.score >= 3.0 && result.score >= topScore * 0.5 { return true }
            return false
        }.prefix(10)

        var lines = ["=== NUTRITIONAL DATABASE MATCHES ==="]
        lines.append("IMPORTANT: Use these values as ground truth anchors. Scale by portion size observed in photo.\n")

        for (idx, result) in relevant.enumerated() {
            let f = result.food
            let rank = idx + 1
            let scoreLabel = result.score >= 15.0 ? "EXACT" : result.score >= 8.0 ? "STRONG" : "PARTIAL"

            if result.score >= 5.0 {
                var entry = "[\(rank)] \(f.name) [\(scoreLabel)] | \(f.serving) (\(f.servingGrams)g)"
                entry += " | Cal: \(f.calories) | P: \(f.protein)g C: \(f.carbs)g F: \(f.fat)g"
                entry += " | Fiber: \(f.fiber)g Sugar: \(f.sugar)g Na: \(f.sodium)mg"
                if !f.notes.isEmpty {
                    entry += "\n    \(f.notes) [confidence: \(f.confidence.rawValue)]"
                }
                lines.append(entry)
            } else {
                lines.append("[\(rank)] \(f.name) [\(scoreLabel)] | \(f.serving) | Cal: \(f.calories) | P: \(f.protein)g C: \(f.carbs)g F: \(f.fat)g")
            }
        }

        // Add calorie density context for top matches
        let densityEntries = relevant.prefix(3).compactMap { result -> String? in
            let f = result.food
            guard f.servingGrams > 0 else { return nil }
            let calPerGram = Double(f.calories) / Double(f.servingGrams)
            let densityLabel: String
            if calPerGram < 0.6 { densityLabel = "LOW density" }
            else if calPerGram < 1.5 { densityLabel = "MEDIUM density" }
            else if calPerGram < 3.0 { densityLabel = "HIGH density" }
            else { densityLabel = "VERY HIGH density" }
            return "  \(f.name): \(String(format: "%.1f", calPerGram)) cal/g (\(densityLabel))"
        }
        if !densityEntries.isEmpty {
            lines.append("\nCALORIE DENSITY REFERENCE (for portion scaling):")
            lines.append(contentsOf: densityEntries)
            lines.append("  Reference: water=0, veggies=0.2-0.5, fruit=0.4-0.8, grains=1.0-1.5, meat=1.5-2.5, fried=2.5-3.5, nuts/oil=5-9")
        }

        if relevant.count < results.count {
            lines.append("\n(\(results.count - relevant.count) lower-relevance matches omitted)")
        }

        return lines.joined(separator: "\n")
    }

    func contextForQuery(_ query: String) -> String {
        let parsed = PortionParser.shared.parse(query)
        let searchTerm = parsed.cleanedFoodName.isEmpty ? query : parsed.cleanedFoodName

        // Check for known meal combos and decompose
        let lowerQuery = searchTerm.lowercased()

        // Fuzzy combo matching: try exact first, then check if query contains a combo key
        var matchedCombo: (key: String, items: [String])?
        if let comboItems = mealCombos[lowerQuery] {
            matchedCombo = (lowerQuery, comboItems)
        } else {
            for (comboKey, comboItems) in mealCombos {
                if lowerQuery.contains(comboKey) || comboKey.contains(lowerQuery) {
                    matchedCombo = (comboKey, comboItems)
                    break
                }
            }
        }

        if let combo = matchedCombo {
            var allResults: [RetrievalResult] = []
            for item in combo.items {
                let itemResults = retrieve(query: item, topK: 1)
                allResults.append(contentsOf: itemResults)
            }
            var context = buildContext(from: allResults)
            context += "\n\nMEAL COMBO DETECTED: \"\(query)\" decomposes into: \(combo.items.joined(separator: " + ")). Sum all components for total calories."
            return context
        }

        // Multi-item photo scan: if query contains commas (Pass 1 output), build per-item context
        let commaItems = query.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if commaItems.count >= 2 {
            return buildMultiItemContext(items: commaItems)
        }

        let results = retrieve(query: searchTerm)
        var context = buildContext(from: results)

        // Compute scale factor using the top result's serving info if available
        if let topResult = results.first {
            let servingInfo = "\(topResult.food.serving) (\(topResult.food.servingGrams)g)"
            let refined = PortionParser.shared.parse(query, standardServing: servingInfo)
            let hint = PortionParser.shared.portionHint(from: refined)
            if !hint.isEmpty {
                context += "\n\nPORTION PARSING: The user's query \"\(query)\" was parsed as: \(hint). "
                context += "Quantity: \(String(format: "%.2g", refined.quantity))"
                if let unit = refined.unit {
                    context += " \(unit)"
                }
                context += ". Scale factor vs standard serving (\(topResult.food.serving)): \(String(format: "%.2f", refined.scaleFactor))x. "
                context += "IMPORTANT: Multiply the base nutritional values by this scale factor."
            }

            // Add visual portion estimation guide
            let portionGuide = visualPortionGuide(for: topResult.food)
            if !portionGuide.isEmpty {
                context += "\n\nPORTION VISUAL GUIDE: \(portionGuide)"
            }
        }

        // Detect cooking method and append calorie hint
        let cookingHint = detectCookingMethod(in: query)
        if !cookingHint.isEmpty {
            context += "\n\nCOOKING METHOD: \(cookingHint)"
        }

        // Add container size estimation hints for photo analysis
        let containerHint = containerSizeHint(for: lowerQuery)
        if !containerHint.isEmpty {
            context += "\n\nCONTAINER HINT: \(containerHint)"
        }

        return context
    }

    /// Build rich per-item context for multi-item photo scans.
    /// Instead of searching all items as one query, retrieves each item individually
    /// for much better matching accuracy.
    private func buildMultiItemContext(items: [String]) -> String {
        var lines = ["=== MULTI-ITEM NUTRITIONAL DATABASE MATCHES ==="]
        lines.append("Each item matched independently for maximum accuracy.\n")

        var totalRefCalories = 0
        var matchCount = 0
        var seenFoods = Set<String>() // Prevent duplicate entries

        for item in items {
            let results = retrieve(query: item, topK: 2)
            if let best = results.first, best.score >= 3.0, !seenFoods.contains(best.food.name.lowercased()) {
                let f = best.food
                seenFoods.insert(f.name.lowercased())

                let calPerG = f.servingGrams > 0 ? String(format: "%.1f", Double(f.calories) / Double(f.servingGrams)) : "?"
                let scoreLabel = best.score >= 15.0 ? "EXACT" : best.score >= 8.0 ? "STRONG" : "PARTIAL"

                var entry = "[\(scoreLabel)] \(item) → \(f.name) | \(f.serving) (\(f.servingGrams)g)"
                entry += " | Cal: \(f.calories) | P: \(f.protein)g C: \(f.carbs)g F: \(f.fat)g | \(calPerG) cal/g"

                if !f.notes.isEmpty {
                    entry += "\n    \(f.notes)"
                }

                // Cooking method hint from item description
                let cookHint = detectCookingMethod(in: item)
                if !cookHint.isEmpty {
                    entry += "\n    Cooking: \(cookHint)"
                }

                // Alternate match for cross-reference
                if results.count > 1, let alt = results.dropFirst().first, alt.score >= 5.0 && alt.food.name != f.name {
                    entry += "\n    Alt: \(alt.food.name) = \(alt.food.calories) cal/\(alt.food.serving)"
                }

                lines.append(entry)
                totalRefCalories += f.calories
                matchCount += 1
            } else {
                lines.append("[NO MATCH] \(item) — use your nutritional knowledge")
            }
        }

        // Summary statistics
        if matchCount > 0 {
            lines.append("\nDATABASE REFERENCE TOTAL: \(matchCount)/\(items.count) items matched, summing to ~\(totalRefCalories) cal at standard portions.")
            lines.append("IMPORTANT: Scale each item's values based on the actual visible portion. These are baseline reference values.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Visual Portion Estimation Guide

    private func visualPortionGuide(for food: FoodItem) -> String {
        let calPerGram = food.servingGrams > 0 ? Double(food.calories) / Double(food.servingGrams) : 0

        switch food.category {
        case .protein:
            return "Protein portions: palm of hand = ~3-4oz (~\(Int(calPerGram * 100))-\(Int(calPerGram * 115)) cal). Deck of cards = ~3oz. Full plate protein = ~6-8oz."
        case .grain:
            return "Grain portions: fist = ~1 cup cooked (~\(food.calories) cal). Tennis ball = ~1/2 cup. Plate of pasta is typically 2-3 cups."
        case .vegetable:
            return "Vegetable portions: fist = ~1 cup. Vegetables are low density (~\(String(format: "%.1f", calPerGram)) cal/g). A full plate of veggies is ~2-3 cups."
        case .fruit:
            return "Fruit portions: fist = ~1 medium fruit. Tennis ball = ~1/2 cup cut fruit."
        case .dairy:
            return "Dairy portions: thumb = ~1oz cheese (~100-110 cal). Dice pair = ~1oz. Cup of yogurt = ~6oz."
        case .fat:
            return "Fat portions: thumb tip = ~1 tsp oil/butter (~40 cal). Thumb = ~1 tbsp (~120 cal). Fats are very calorie-dense (\(String(format: "%.1f", calPerGram)) cal/g)."
        case .fastFood, .restaurant:
            return "Restaurant portions are typically 1.5-2x standard servings. A restaurant plate of food is usually 600-1200 cal total."
        case .snack, .sweet:
            return "Snack portions: small bag = ~1oz (~\(Int(calPerGram * 28)) cal). Handful = ~1oz. Full-size bag = ~2.5-3 servings."
        case .beverage:
            return "Beverage sizes: small/tall = 12oz, medium/grande = 16oz, large/venti = 20-24oz. Standard can = 12oz."
        case .mixed:
            return "Mixed dish: a standard dinner plate is ~10 inches. Food filling 2/3 of plate is ~1.5-2 servings."
        default:
            return ""
        }
    }

    // MARK: - Container Size Hints

    private func containerSizeHint(for query: String) -> String {
        let containerHints: [(keywords: [String], hint: String)] = [
            (["bowl", "soup bowl"], "Standard bowl = 12-16oz. Soup bowl = 8-12oz. Large/oversized bowl = 20-24oz."),
            (["plate", "dinner plate", "platter"], "Standard dinner plate = 10-11 inches. Salad plate = 7-8 inches. If food fills the plate, it's likely 1.5-2x a standard serving."),
            (["cup", "mug"], "Standard cup = 8oz. Coffee mug = 10-12oz. Travel mug = 16-20oz."),
            (["glass", "tumbler"], "Standard glass = 8-10oz. Tall glass = 12-16oz. Pint glass = 16oz."),
            (["box", "container", "takeout"], "Standard takeout container = 16-32oz. Chinese takeout box = ~20oz. Fast food box = 1 serving."),
            (["bag", "packet", "pack"], "Single-serve bag = 1-1.5oz. Snack bag = 2-3oz. Share size = 3-5oz. Family size = 10-16oz."),
            (["slice", "piece"], "Pizza slice = 1/8 of large pie. Cake slice = 1/8 to 1/12 of cake. Bread slice = ~1oz."),
            (["wrap", "burrito", "roll"], "Standard burrito = 10-12 inch tortilla, ~12-16oz filled. Wrap = 8-10 inch, ~8-12oz filled."),
            (["scoop", "ball"], "Ice cream scoop = ~1/2 cup (~65-70g). Restaurant scoop is often larger = ~3/4 cup."),
        ]

        for hint in containerHints {
            if hint.keywords.contains(where: { query.contains($0) }) {
                return hint.hint
            }
        }
        return ""
    }

    // MARK: - Cooking Method Detection

    /// Public accessor for cooking method detection (used by ClaudeNutritionService for per-item anchors)
    func detectCookingMethodPublic(in query: String) -> String {
        return detectCookingMethod(in: query)
    }

    private func detectCookingMethod(in query: String) -> String {
        let lower = query.lowercased()
        for (method, hint) in cookingMethodHints {
            if lower.contains(method) {
                return "\(hint) Adjust calories accordingly for \"\(method)\" preparation."
            }
        }
        return ""
    }

    // MARK: - Multi-Item Query Detection

    private func splitMultiItemQuery(_ query: String) -> [String] {
        var protected = query
        var placeholders: [String: String] = [:]
        for (index, compound) in compoundFoods.enumerated() {
            if protected.contains(compound) {
                let placeholder = "COMPOUND\(index)"
                protected = protected.replacingOccurrences(of: compound, with: placeholder)
                placeholders[placeholder] = compound
            }
        }

        let separatorPattern = #"\s+and\s+|\s*,\s*|\s+plus\s+|\s*&\s*|\s+with\s+a\s+"#
        guard let regex = try? NSRegularExpression(pattern: separatorPattern, options: .caseInsensitive) else {
            return [query]
        }

        let range = NSRange(protected.startIndex..., in: protected)
        var parts = regex.stringByReplacingMatches(in: protected, range: range, withTemplate: "|||")
            .components(separatedBy: "|||")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        parts = parts.map { part in
            var restored = part
            for (placeholder, compound) in placeholders {
                restored = restored.replacingOccurrences(of: placeholder, with: compound)
            }
            return restored
        }

        return parts.isEmpty ? [query] : parts
    }

    // MARK: - Spelling Correction (pre-processing)

    /// Common misspellings → correct spelling. Applied before tokenization.
    private let misspellings: [String: String] = [
        // Proteins
        "chiken": "chicken", "chickin": "chicken", "chciken": "chicken", "chickn": "chicken",
        "chicken brest": "chicken breast",
        "salman": "salmon", "samon": "salmon", "samlon": "salmon",
        "tunna": "tuna", "tinna": "tuna",
        "shrim": "shrimp", "shimp": "shrimp", "shrmp": "shrimp",
        "turky": "turkey", "terkey": "turkey", "trukey": "turkey",
        "staek": "steak", "steek": "steak",
        "hamberger": "hamburger", "hamburgar": "hamburger", "hambuger": "hamburger",
        "sasuage": "sausage", "sauage": "sausage", "sasauge": "sausage", "sausge": "sausage",
        "bakon": "bacon", "baccon": "bacon",
        // Dairy
        "yougurt": "yogurt", "yoghurt": "yogurt", "yougrt": "yogurt", "yogart": "yogurt",
        "chese": "cheese", "cheeze": "cheese", "chesse": "cheese",
        "millk": "milk", "mlk": "milk",
        // Grains
        "bred": "bread", "braed": "bread",
        "passta": "pasta", "psta": "pasta",
        "sandwhich": "sandwich", "sandwitch": "sandwich", "sanwich": "sandwich", "sammich": "sandwich", "samwich": "sandwich",
        "tortila": "tortilla", "tortillia": "tortilla", "tortiya": "tortilla",
        "buritto": "burrito", "burito": "burrito", "burritto": "burrito",
        "cerial": "cereal", "ceral": "cereal",
        "oatmal": "oatmeal", "oatmel": "oatmeal",
        // Fruits & Vegetables
        "avacado": "avocado", "avacodo": "avocado", "avocato": "avocado",
        "brocoli": "broccoli", "brocolli": "broccoli", "broccolli": "broccoli",
        "tomatoe": "tomato",
        "potatos": "potatoes", "potatoe": "potato", "potaoe": "potato",
        "bannana": "banana", "bananna": "banana", "banan": "banana",
        "strawbery": "strawberry", "stawberry": "strawberry",
        "blubery": "blueberry", "bluberry": "blueberry",
        "letuce": "lettuce", "lettice": "lettuce",
        "spinnach": "spinach", "spinich": "spinach",
        "oinon": "onion", "onnion": "onion",
        "pinapple": "pineapple", "pinnaple": "pineapple",
        "watermellon": "watermelon", "watermelone": "watermelon",
        // Fast food / restaurants
        "chipottle": "chipotle", "chiptole": "chipotle", "chipolte": "chipotle",
        "mcdonals": "mcdonalds", "mconalds": "mcdonalds", "macdonalds": "mcdonalds",
        "chik fil a": "chick fil a", "chic fil a": "chick fil a", "chickfila": "chick fil a",
        "starbacks": "starbucks", "starbuck": "starbucks",
        "subwey": "subway", "subay": "subway",
        // Common foods
        "quesadila": "quesadilla", "quesadilia": "quesadilla", "quesidilla": "quesadilla",
        "guacamoly": "guacamole", "guacomole": "guacamole",
        "calzoney": "calzone",
        "pankcake": "pancake",
        "wafle": "waffle",
        "cinamon": "cinnamon", "cinnammon": "cinnamon",
        "ceasar": "caesar", "ceaser": "caesar",
        "protien": "protein", "protine": "protein",
        "caleries": "calories",
        "macoroni": "macaroni", "macaronni": "macaroni",
        "spagetti": "spaghetti", "spageti": "spaghetti", "spagehtti": "spaghetti",
        "fettucine": "fettuccine", "fetuccine": "fettuccine",
        "lasanga": "lasagna", "lasagne": "lasagna",
        "rissoto": "risotto", "risoto": "risotto",
        "cofee": "coffee", "coffe": "coffee", "cofe": "coffee",
        "expresso": "espresso",
        "capuccino": "cappuccino", "cappucino": "cappuccino",
        "smoothe": "smoothie", "smoothee": "smoothie",
        "chocolat": "chocolate", "choclate": "chocolate", "chocalate": "chocolate",
        "peanutbutter": "peanut butter", "peanutbuter": "peanut butter",
        "cabage": "cabbage",
        "zuchini": "zucchini", "zuccini": "zucchini",
        "califlower": "cauliflower", "cauliflour": "cauliflower",
        // More proteins
        "tillapia": "tilapia",
        "hallibutt": "halibut",
        "lobstar": "lobster", "lobser": "lobster",
        "scalop": "scallop",
        "venason": "venison",
        "prosciuto": "prosciutto", "proscuitto": "prosciutto",
        // More international foods
        "fettucini": "fettuccine", "fettuchinni": "fettuccine",
        "gnocci": "gnocchi", "gnochi": "gnocchi",
        "bruscheta": "bruschetta", "bruchetta": "bruschetta",
        "focacia": "focaccia",
        "pretzle": "pretzel", "pretsel": "pretzel",
        "croisant": "croissant", "crossant": "croissant", "croissont": "croissant",
        "baguete": "baguette", "baguett": "baguette",
        "acaii": "acai", "assai": "acai",
        "edamami": "edamame",
        "gioza": "gyoza",
        "tempurra": "tempura",
        "teryaki": "teriyaki", "terriaki": "teriyaki",
        "shwarma": "shawarma", "schwarma": "shawarma",
        "falafl": "falafel", "felafel": "falafel", "falafle": "falafel",
        "hummas": "hummus", "humus": "hummus", "hummous": "hummus",
        "tahin": "tahini", "tahine": "tahini",
        "bibimbop": "bibimbap", "bibimbab": "bibimbap",
        "bulgoki": "bulgogi",
        "tteokboki": "tteokbokki", "topokki": "tteokbokki",
        "phoh": "pho",
        "bahn mi": "banh mi", "ban mi": "banh mi",
        "biriyani": "biryani", "briyani": "biryani",
        "somosa": "samosa",
        "tikka massala": "tikka masala", "tika masala": "tikka masala",
        "enjera": "injera",
        "tiramissu": "tiramisu", "tiramasu": "tiramisu",
        "canoli": "cannoli", "cannolli": "cannoli",
        "baklawa": "baklava", "baclava": "baklava",
        "churos": "churros", "churro": "churros",
        "crep": "crepe",
        "sufle": "souffle",
        "kambucha": "kombucha", "kombuca": "kombucha",
        // Fast food misspellings
        "whataberger": "whataburger", "whatburger": "whataburger",
        "culver": "culvers",
        "wendies": "wendys",
        "popeys": "popeyes", "popyes": "popeyes",
        "chpotle": "chipotle",
        "wingstops": "wingstop",
        "shakeshack": "shake shack",
        "innout": "in n out", "in and out": "in n out",
        "raisin canes": "raising canes", "cains": "raising canes",
        // Desserts
        "brownee": "brownie",
        "cheescake": "cheesecake", "cheezecake": "cheesecake",
        "macaroon": "macaron", "macron": "macaron",
        "merange": "meringue",
    ]

    /// Abbreviations and slang → full food names
    private let abbreviations: [String: String] = [
        // Proteins
        "chx": "chicken", "chkn": "chicken",
        "bf": "ground beef", "grd bf": "ground beef",
        "grnd beef": "ground beef", "grnd turkey": "ground turkey",
        "grnd chx": "ground chicken",
        // Sandwiches
        "sw": "sandwich", "sammy": "sandwich", "sammie": "sandwich", "sando": "sandwich",
        "pb&j": "peanut butter and jelly", "pbj": "peanut butter and jelly",
        "pb": "peanut butter",
        "blt": "bacon lettuce tomato sandwich",
        "bec": "bacon egg cheese sandwich",
        "sec": "sausage egg cheese sandwich",
        // Beverages
        "oj": "orange juice", "aj": "apple juice", "gj": "grape juice",
        "ff": "french fries",
        // Burgers
        "bg": "burger", "burg": "burger",
        "cb": "cheeseburger",
        "dd": "double double",
        // Fast food
        "nugs": "chicken nuggets", "nuggets": "chicken nuggets", "tendies": "chicken tenders",
        "tots": "tater tots",
        "za": "pizza", "zza": "pizza",
        "mac": "macaroni and cheese", "mac n cheese": "macaroni and cheese",
        // Breakfast
        "oats": "oatmeal", "overnights": "overnight oats",
        // Produce
        "avo": "avocado",
        "broc": "broccoli",
        "parm": "parmesan",
        "sp": "sweet potato", "swt pot": "sweet potato",
        "cauli": "cauliflower",
        "zuke": "zucchini", "zucc": "zucchini",
        // Salads
        "cobb": "cobb salad",
        "cae": "caesar salad", "caes": "caesar salad",
        // Bowl meals
        "acb": "acai bowl",
        "poke": "poke bowl",
        "bb": "burrito bowl",
        // Health/diet
        "gf": "gluten free",
        "df": "dairy free",
        "v": "vegan",
        "vg": "vegetarian",
        "keto": "keto friendly",
        // Protein supplements
        "whey": "whey protein",
        "pre": "pre workout",
        "bcaa": "branched chain amino acids",
        // Starbucks sizes
        "sbux": "starbucks",
        "venti": "venti starbucks",
        "grande": "grande starbucks",
        // Common texting abbreviations
        "chz": "cheese",
        "tom": "tomato",
        "mush": "mushroom",
        "pep": "pepperoni",
        "jalapenos": "jalapeno peppers",
        "hb": "hamburger",
    ]

    /// Apply spelling corrections and abbreviation expansion to raw query
    private func correctSpelling(_ query: String) -> String {
        var result = query.lowercased()

        // First check if the full query matches a known misspelling
        if let corrected = misspellings[result] {
            return corrected
        }

        // Check abbreviations (full query match)
        if let expanded = abbreviations[result] {
            return expanded
        }

        // Token-level correction
        var tokens = result.split(separator: " ").map { String($0) }
        var changed = false
        for (i, token) in tokens.enumerated() {
            if let corrected = misspellings[token] {
                tokens[i] = corrected
                changed = true
            } else if let expanded = abbreviations[token] {
                tokens[i] = expanded
                changed = true
            }
        }

        // Also check 2-word pairs for multi-word misspellings
        if tokens.count >= 2 {
            var i = 0
            while i < tokens.count - 1 {
                let pair = "\(tokens[i]) \(tokens[i+1])"
                if let corrected = misspellings[pair] {
                    tokens[i] = corrected
                    tokens.remove(at: i + 1)
                    changed = true
                }
                i += 1
            }
        }

        return changed ? tokens.joined(separator: " ") : result
    }

    // MARK: - Personal Frequency Boosting

    /// Boost score for foods the user has logged before. Logged 10+ times = +15% boost.
    private func applyFrequencyBoost(_ score: Double, food: FoodItem, frequencyMap: [String: Int]) -> Double {
        let key = food.name.lowercased()
        guard let count = frequencyMap[key], count > 0 else { return score }
        // Logarithmic boost: log2(count+1) * 0.05, capped at 20%
        let boost = min(0.20, log2(Double(count) + 1) * 0.05)
        return score * (1.0 + boost)
    }

    // MARK: - Negative Modifier Penalty

    /// Penalize results where the cooking method contradicts the query.
    /// e.g., user says "grilled chicken" but we match "fried chicken"
    private func applyNegativeModifierPenalty(_ score: Double, query: String, food: FoodItem) -> Double {
        let conflictingPairs: [(queried: String, penalize: String)] = [
            // Cooking methods
            ("grilled", "fried"), ("grilled", "deep fried"), ("grilled", "breaded"),
            ("baked", "fried"), ("baked", "deep fried"),
            ("steamed", "fried"), ("steamed", "deep fried"),
            ("air fried", "deep fried"),
            ("fried", "grilled"), ("fried", "baked"), ("fried", "steamed"),
            ("raw", "cooked"), ("raw", "fried"), ("raw", "grilled"), ("raw", "baked"),
            ("roasted", "fried"), ("roasted", "boiled"),
            ("smoked", "fried"), ("smoked", "grilled"),
            ("poached", "fried"), ("poached", "grilled"),
            ("braised", "fried"), ("braised", "grilled"),
            ("blackened", "fried"), ("sauteed", "deep fried"),
            // Preparation style
            ("skinless", "skin on"), ("boneless", "bone in"),
            ("crispy", "steamed"), ("crispy", "boiled"),
            ("plain", "loaded"), ("plain", "stuffed"), ("plain", "topped"),
            // Diet modifiers
            ("diet", "regular"), ("sugar free", "regular"), ("sugar free", "sweetened"),
            ("light", "regular"), ("lite", "regular"),
            ("low fat", "full fat"), ("nonfat", "whole"), ("skim", "whole"),
            ("zero calorie", "regular"), ("zero sugar", "regular"),
            ("decaf", "regular"), ("unsweetened", "sweetened"),
            ("thin crust", "deep dish"), ("deep dish", "thin crust"),
            // Grain types
            ("whole wheat", "white"), ("wheat", "white"),
            ("multigrain", "white"), ("sourdough", "white"),
            ("brown rice", "white rice"), ("white rice", "brown rice"),
            ("cauliflower", "regular"),
            // Bean types
            ("black", "pinto"), ("pinto", "black"), ("kidney", "black"), ("navy", "black"),
            // Protein types
            ("chicken", "beef"), ("beef", "chicken"), ("pork", "chicken"),
            ("turkey", "beef"), ("veggie", "beef"), ("beyond", "regular"),
            ("impossible", "regular"), ("plant based", "beef"),
            ("salmon", "tilapia"), ("tuna", "salmon"),
            // Size conflicts
            ("small", "large"), ("large", "small"),
            ("junior", "large"), ("mini", "regular"),
        ]

        let foodNameLower = food.name.lowercased() + " " + food.notes.lowercased()

        for pair in conflictingPairs {
            if query.contains(pair.queried) && foodNameLower.contains(pair.penalize) {
                return score * 0.5 // 50% penalty for contradicting modifier
            }
        }
        return score
    }

    // MARK: - Scoring Algorithm

    private func scoreFood(_ cached: IndexEntry, food: FoodItem, query: String, queryTokens: [String], rawTokenCount: Int) -> (Double, [String]) {
        var score: Double = 0
        var matchedTerms: [String] = []
        var tokensMatched = 0

        let normalizedName = cached.normalizedName
        let normalizedAliases = cached.normalizedAliases

        // Tier 1: Exact full-name match (+20)
        if normalizedName == query {
            score += 20
            matchedTerms.append("exact-name:\(food.name)")
        }
        // Tier 1b: Name starts with query or query starts with name (+10)
        else if normalizedName.hasPrefix(query) || query.hasPrefix(normalizedName) {
            score += 10
            matchedTerms.append("prefix-name:\(food.name)")
        }

        // Tier 2: Alias matching — exact (+18), partial bidirectional (+12)
        for alias in normalizedAliases {
            if alias == query {
                score += 18
                matchedTerms.append("exact-alias:\(alias)")
            } else if alias.contains(query) || query.contains(alias) {
                score += 12
                matchedTerms.append("partial-alias:\(alias)")
            }
        }

        // Tier 3: Token-level matching with IDF-weighted fuzzy + prefix support
        let filteredTokens = queryTokens.filter { !sizeModifiers.contains($0) }

        for token in filteredTokens {
            let idf = index.idfWeight(for: token)

            if normalizedName.contains(token) {
                score += 5 * idf
                matchedTerms.append("name-token:\(token)")
                tokensMatched += 1
            } else if prefixMatchesWord(token: token, in: cached.nameWords) {
                // Prefix matching: "chick" matches "chicken"
                score += 4.5 * idf
                matchedTerms.append("prefix-name:\(token)")
                tokensMatched += 1
            } else if let fuzzyMatch = fuzzyMatchWords(token: token, words: cached.nameWords) {
                score += 3.5 * idf
                matchedTerms.append("fuzzy-name:\(token)~\(fuzzyMatch)")
                tokensMatched += 1
            } else {
                var matched = false

                // Check aliases (exact substring)
                for alias in normalizedAliases {
                    if alias.contains(token) {
                        score += 4 * idf
                        matchedTerms.append("alias-token:\(token)")
                        matched = true
                        tokensMatched += 1
                        break
                    }
                }

                // Check aliases (prefix match on words)
                if !matched {
                    for aliasWords in cached.aliasWordSets {
                        if prefixMatchesWord(token: token, in: aliasWords) {
                            score += 3.5 * idf
                            matchedTerms.append("prefix-alias:\(token)")
                            matched = true
                            tokensMatched += 1
                            break
                        }
                    }
                }

                // Check aliases (fuzzy)
                if !matched {
                    for aliasWords in cached.aliasWordSets {
                        if fuzzyMatchWords(token: token, words: aliasWords) != nil {
                            score += 2.5 * idf
                            matchedTerms.append("fuzzy-alias:\(token)")
                            matched = true
                            tokensMatched += 1
                            break
                        }
                    }
                }

                if !matched {
                    if cached.normalizedCategory.contains(token) || cached.normalizedSubCategory.contains(token) {
                        score += 2
                        matchedTerms.append("category-token:\(token)")
                        tokensMatched += 1
                    } else {
                        let tagMatch = cached.normalizedTags.contains { $0.contains(token) }
                        if tagMatch {
                            score += 1.5
                            matchedTerms.append("tag-token:\(token)")
                            tokensMatched += 1
                        } else if cached.normalizedNotes.contains(token) {
                            score += 0.5
                            matchedTerms.append("notes-token:\(token)")
                            tokensMatched += 1
                        }
                    }
                }
            }
        }

        // Tier 4: Token coverage multiplier — reward matching more query tokens
        if rawTokenCount > 1 && !filteredTokens.isEmpty {
            let coverage = Double(tokensMatched) / Double(min(filteredTokens.count, rawTokenCount))
            // Full coverage (1.0) gets 1.5x boost, no coverage gets 0.7x penalty
            let coverageMultiplier = 0.7 + (coverage * 0.8)
            score *= coverageMultiplier
            if coverage >= 0.8 {
                matchedTerms.append("coverage:\(String(format: "%.0f", coverage * 100))%")
            }
        }

        // Tier 5: Category inference bonus
        let categoryBonus = inferCategoryBonus(query: query, queryTokens: queryTokens, foodCategory: food.category)
        if categoryBonus > 0 {
            score += categoryBonus
            matchedTerms.append("category-bonus:\(food.category.rawValue)")
        }

        // Tier 6: Confidence multiplier
        let multiplier: Double
        switch food.confidence {
        case .high: multiplier = 1.0
        case .medium: multiplier = 0.95
        case .low: multiplier = 0.85
        }

        score *= multiplier

        return (score, matchedTerms)
    }

    // MARK: - Prefix Matching

    private func prefixMatchesWord(token: String, in words: [String]) -> Bool {
        guard token.count >= 3 else { return false }
        return words.contains { word in
            word.hasPrefix(token) && word.count > token.count
        }
    }

    // MARK: - Fuzzy Matching (Levenshtein Distance)

    private func fuzzyMatchWords(token: String, words: [String]) -> String? {
        guard token.count >= 3 else { return nil }
        let maxDist = maxEditDistance(for: token)
        for word in words {
            if levenshteinDistance(token, word) <= maxDist {
                return word
            }
        }
        return nil
    }

    private func maxEditDistance(for token: String) -> Int {
        if token.count <= 3 { return 1 }
        return token.count <= 6 ? 1 : 2
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1.utf8)
        let b = Array(s2.utf8)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        // Early exit: if length difference exceeds max possible edit distance, skip
        if abs(m - n) > 2 { return abs(m - n) }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,      // deletion
                    curr[j - 1] + 1,   // insertion
                    prev[j - 1] + cost // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    // MARK: - Category Inference

    private func inferCategoryBonus(query: String, queryTokens: [String], foodCategory: FoodCategory) -> Double {
        let categoryKeywords: [(keywords: [String], category: FoodCategory, bonus: Double)] = [
            // Fast food brands
            (["starbucks", "sbux", "starbs"], .fastFood, 4),
            (["mcdonalds", "mcd", "mcdonald", "mickey ds", "maccas"], .fastFood, 4),
            (["chipotle"], .fastFood, 4),
            (["chick fil a", "chickfila", "cfa", "chikfila"], .fastFood, 4),
            (["taco bell", "tb", "tacobell"], .fastFood, 4),
            (["wendys", "wendy", "wendies"], .fastFood, 4),
            (["subway"], .fastFood, 4),
            (["five guys", "5 guys", "fiveguys"], .fastFood, 4),
            (["dominos", "dominoes", "pizza hut", "domino"], .fastFood, 4),
            (["kfc", "popeyes", "popeye"], .fastFood, 4),
            (["shake shack", "shakeshack"], .fastFood, 4),
            (["dunkin", "krispy kreme", "dunkindonuts"], .fastFood, 4),
            (["panda express", "pandaexpress"], .fastFood, 4),
            (["in n out", "innout", "in and out"], .fastFood, 4),
            (["raising canes", "canes", "raisin canes"], .fastFood, 4),
            (["wingstop", "wing stop"], .fastFood, 4),
            (["sonic", "sonic drive"], .fastFood, 3),
            (["panera", "panera bread"], .fastFood, 3),
            (["jersey mikes", "jersey mike"], .fastFood, 3),
            (["whataburger", "culvers", "zaxbys", "portillos"], .fastFood, 3),
            (["sweetgreen", "sweet green"], .fastFood, 3),
            // Beverages
            (["coffee", "latte", "espresso", "cappuccino", "mocha", "americano", "macchiato"], .beverage, 3),
            (["tea", "matcha", "chai", "boba", "bubble tea"], .beverage, 3),
            (["smoothie", "juice", "shake", "protein shake"], .beverage, 2),
            (["beer", "wine", "cocktail", "margarita", "vodka", "whiskey", "rum", "tequila", "bourbon"], .beverage, 3),
            (["soda", "coke", "pepsi", "sprite", "fanta", "dr pepper"], .beverage, 3),
            (["water", "sparkling", "seltzer"], .beverage, 3),
            // Food categories
            (["breakfast", "brunch", "morning"], .mixed, 2),
            (["protein", "lean", "muscle", "gym"], .protein, 2),
            (["salad", "greens", "veggie", "vegetable"], .vegetable, 2),
            (["fruit", "berry", "berries"], .fruit, 2),
            (["dessert", "sweet", "cake", "cookie", "candy", "chocolate", "ice cream", "pastry"], .snack, 2),
            (["pasta", "bread", "rice", "grain", "cereal", "oat", "oatmeal", "noodle"], .grain, 2),
            (["cheese", "yogurt", "milk", "dairy", "butter", "cream"], .dairy, 2),
            (["sauce", "dressing", "dip", "condiment", "syrup", "ketchup", "mayo", "mustard"], .condiment, 2),
            (["supplement", "powder", "creatine", "whey", "preworkout", "vitamin"], .supplement, 3),
            (["burger", "fries", "fast food", "drive thru", "nuggets", "mcnuggets"], .fastFood, 2),
            (["burger king", "bk", "whopper"], .fastFood, 4),
            (["arbys", "arby"], .fastFood, 3),
            (["sushi", "ramen", "pho", "thai", "chinese", "indian", "korean", "japanese", "mexican", "italian", "mediterranean", "greek", "vietnamese"], .restaurant, 2),
            (["ethiopian", "injera", "wot", "tibs", "kitfo"], .restaurant, 3),
            (["korean", "bulgogi", "kimchi", "tteokbokki", "kimbap", "japchae"], .restaurant, 3),
            (["caribbean", "jamaican", "jerk", "oxtail", "plantain"], .restaurant, 3),
            (["filipino", "adobo", "lumpia", "pancit", "sinigang"], .restaurant, 3),
            (["african", "nigerian", "ghanaian", "jollof", "suya", "fufu"], .restaurant, 3),
            (["turkish", "doner", "kebab", "shawarma", "lahmacun"], .restaurant, 3),
            (["persian", "iranian", "tahdig", "ghormeh"], .restaurant, 3),
            (["southern", "soul food", "cajun", "creole", "gumbo", "jambalaya"], .restaurant, 2),
            (["acai", "smoothie bowl", "pitaya"], .mixed, 2),
            (["meal prep", "bodybuilding", "macro"], .mixed, 2),
            (["nut", "seed", "almond", "cashew", "peanut", "walnut", "pecan", "pistachio"], .fat, 2),
            (["bean", "lentil", "chickpea", "tofu", "tempeh", "edamame"], .legume, 2),
        ]

        var bonus: Double = 0
        for mapping in categoryKeywords {
            let queryMatches = mapping.keywords.contains { keyword in
                query.contains(keyword) || queryTokens.contains(keyword)
            }
            if queryMatches && foodCategory == mapping.category {
                bonus = max(bonus, mapping.bonus)
            }
        }
        return bonus
    }

    // MARK: - Size/Quantity Modifiers (filtered from scoring, passed to Claude via raw text)

    private let sizeModifiers: Set<String> = [
        "large", "small", "medium", "extra", "big", "little", "huge", "tiny",
        "double", "triple", "single", "half", "quarter", "third",
        "handful", "couple", "few", "serving", "portion", "piece", "slice",
        "regular", "grande", "venti", "tall", "king", "super", "jumbo",
        "mini", "junior", "senior", "family", "personal",
        "cup", "bowl", "plate", "scoop", "tablespoon", "teaspoon",
        "ounce", "oz", "gram", "pound", "lb",
    ]

    // MARK: - Synonym Expansion

    private func expandWithSynonyms(_ tokens: [String]) -> [String] {
        var expanded = tokens
        for token in tokens {
            if let synonymList = synonyms[token] {
                for synonym in synonymList {
                    let synonymTokens = synonym.split(separator: " ").map { String($0) }
                    expanded.append(contentsOf: synonymTokens)
                }
            }
        }
        return expanded
    }

    // MARK: - Text Processing

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenize(_ text: String) -> [String] {
        let stopwords: Set<String> = [
            "a", "an", "the", "of", "with", "and", "or", "for", "in", "on", "at", "to",
            "is", "it", "i", "me", "my", "had", "ate", "eat", "eating", "have", "some",
            "from", "just", "like", "about", "was", "were", "been", "that", "this",
            "but", "not", "then", "also", "got", "get"
        ]
        return text.split(separator: " ")
            .map { String($0) }
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }
}

// MARK: - Pre-built Inverted Index

/// Cached pre-normalized data for a single food item.
struct IndexEntry: Sendable {
    let normalizedName: String
    let nameWords: [String]
    let normalizedAliases: [String]
    let aliasWordSets: [[String]]
    let normalizedCategory: String
    let normalizedSubCategory: String
    let normalizedTags: [String]
    let normalizedNotes: String
    /// All unique tokens from name + aliases for inverted index
    let allTokens: Set<String>
    /// 3-char prefixes of all name/alias words for prefix matching
    let prefixes: Set<String>
}

/// Pre-built index for fast food retrieval.
/// Built once from the food database; invalidated when DB changes.
struct FoodIndex: Sendable {
    let entries: [IndexEntry]
    /// Token → set of food indices that contain this token
    private let invertedIndex: [String: [Int]]
    /// 3-char prefix → set of food indices
    private let prefixIndex: [String: [Int]]
    /// IDF weights
    private let idf: [String: Double]

    init(foods: [FoodItem], normalize: (String) -> String, synonyms: [String: [String]]) {
        var entries: [IndexEntry] = []
        var inverted: [String: [Int]] = [:]
        var prefIdx: [String: [Int]] = [:]
        var documentFrequency: [String: Int] = [:]
        let totalDocs = Double(foods.count)

        entries.reserveCapacity(foods.count)

        for (i, food) in foods.enumerated() {
            let normName = normalize(food.name)
            let nameWords = normName.split(separator: " ").map { String($0) }
            let normAliases = food.aliases.map { normalize($0) }
            let aliasWordSets = normAliases.map { $0.split(separator: " ").map { String($0) } }

            // Collect all tokens
            var allTokens = Set<String>(nameWords)
            for aliasWords in aliasWordSets {
                allTokens.formUnion(aliasWords)
            }

            // Also add synonym expansions of all tokens
            var expandedTokens = allTokens
            for token in allTokens {
                if let syns = synonyms[token] {
                    for syn in syns {
                        for word in syn.split(separator: " ") {
                            expandedTokens.insert(String(word))
                        }
                    }
                }
            }

            // Build 3-char prefixes
            var prefixes = Set<String>()
            for token in allTokens where token.count >= 3 {
                let prefix = String(token.prefix(3))
                prefixes.insert(prefix)
            }

            // Document frequency for IDF
            for token in allTokens {
                documentFrequency[token, default: 0] += 1
            }

            let entry = IndexEntry(
                normalizedName: normName,
                nameWords: nameWords,
                normalizedAliases: normAliases,
                aliasWordSets: aliasWordSets,
                normalizedCategory: normalize(food.category.rawValue),
                normalizedSubCategory: normalize(food.subCategory),
                normalizedTags: food.tags.map { normalize($0) },
                normalizedNotes: normalize(food.notes),
                allTokens: expandedTokens,
                prefixes: prefixes
            )
            entries.append(entry)

            // Inverted index: token → [food indices]
            for token in expandedTokens {
                inverted[token, default: []].append(i)
            }

            // Prefix index: 3-char prefix → [food indices]
            for prefix in prefixes {
                prefIdx[prefix, default: []].append(i)
            }
        }

        // Compute IDF weights
        var idfWeights: [String: Double] = [:]
        for (token, df) in documentFrequency {
            idfWeights[token] = min(3.0, max(1.0, log(totalDocs / Double(df))))
        }

        self.entries = entries
        self.invertedIndex = inverted
        self.prefixIndex = prefIdx
        self.idf = idfWeights
    }

    func idfWeight(for token: String) -> Double {
        idf[token] ?? 2.0
    }

    /// Return candidate food indices that might match the given tokens/query.
    /// Uses inverted index + prefix index to avoid full O(n) scan.
    func candidates(for tokens: [String], query: String) -> Set<Int> {
        var result = Set<Int>()

        for token in tokens {
            // Exact token match via inverted index
            if let indices = invertedIndex[token] {
                result.formUnion(indices)
            }

            // Prefix match: look up 3-char prefix
            if token.count >= 3 {
                let prefix = String(token.prefix(3))
                if let indices = prefixIndex[prefix] {
                    result.formUnion(indices)
                }
            }
        }

        // Also check if any entry's normalized name contains the full query
        // (handles cases where the query is a substring of a food name)
        // Only do this for short queries to avoid O(n) scan on long queries
        if query.count <= 20 {
            for (i, entry) in entries.enumerated() {
                if entry.normalizedName.contains(query) {
                    result.insert(i)
                }
                if result.count > entries.count / 2 { break } // too many candidates, bail
            }
        }

        return result
    }
}
