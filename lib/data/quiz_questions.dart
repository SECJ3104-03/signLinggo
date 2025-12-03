// Create this file: lib/data/quiz_questions.dart
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;
  final String category;
  final String? imageAsset; // Optional: for visual questions
  final String? videoAsset; // Optional: for video questions

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
    this.category = 'General',
    this.imageAsset,
    this.videoAsset,
  });
}

class QuizRepository {
  // ─── GREETINGS CATEGORY ─────────────────────────────────────
  static final List<QuizQuestion> greetingQuestions = [
    QuizQuestion(
      question: 'What is the sign for "Hello"?',
      options: [
        'Wave hand side to side',
        'Thumbs up',
        'Peace sign',
        'Hand on heart'
      ],
      correctAnswerIndex: 0,
      explanation: 'Waving hand side to side is the international sign for greeting someone.',
      category: 'Greetings',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Goodbye"?',
      options: [
        'Open and close hand',
        'Wave hand up and down',
        'Peace sign outward',
        'Hand to forehead'
      ],
      correctAnswerIndex: 0,
      explanation: 'Goodbye is signed by opening and closing your hand, like waving goodbye.',
      category: 'Greetings',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Thank you"?',
      options: [
        'Hand moves from chin outward',
        'Two thumbs up',
        'Clapping hands',
        'Finger to lips'
      ],
      correctAnswerIndex: 0,
      explanation: 'Move your flat hand from your chin outward to show gratitude.',
      category: 'Greetings',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Please"?',
      options: [
        'Flat hand circles on chest',
        'Open palm facing up',
        'Hand tapping chest',
        'Fingers to mouth'
      ],
      correctAnswerIndex: 0,
      explanation: 'Make a circular motion with your flat hand on your chest.',
      category: 'Greetings',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Sorry"?',
      options: [
        'Closed fist circles on chest',
        'Hand over heart',
        'Bowing head',
        'Palms together'
      ],
      correctAnswerIndex: 0,
      category: 'Greetings',
    ),
  ];

  // ─── NUMBERS CATEGORY ──────────────────────────────────────
  static final List<QuizQuestion> numberQuestions = [
    QuizQuestion(
      question: 'What is the sign for number "1"?',
      options: [
        'Index finger up',
        'Thumb up',
        'Peace sign',
        'All fingers folded'
      ],
      correctAnswerIndex: 0,
      category: 'Numbers',
    ),
    
    QuizQuestion(
      question: 'What is the sign for number "5"?',
      options: [
        'All five fingers spread',
        'Thumb and pinky out',
        'Closed fist',
        'Peace sign plus thumb'
      ],
      correctAnswerIndex: 0,
      category: 'Numbers',
    ),
    
    QuizQuestion(
      question: 'What is the sign for number "10"?',
      options: [
        'Thumb up and shake',
        'Two hands showing five',
        'Make a fist with thumb out',
        'Index fingers cross'
      ],
      correctAnswerIndex: 2,
      category: 'Numbers',
    ),
  ];

  // ─── FAMILY CATEGORY ───────────────────────────────────────
  static final List<QuizQuestion> familyQuestions = [
    QuizQuestion(
      question: 'What is the sign for "Mother"?',
      options: [
        'Thumb taps chin',
        'Open hand on chest',
        'Fingers spread on cheek',
        'Hand to forehead'
      ],
      correctAnswerIndex: 0,
      category: 'Family',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Father"?',
      options: [
        'Thumb taps forehead',
        'Hand on chest',
        'Closed fist on chin',
        'Open palm on cheek'
      ],
      correctAnswerIndex: 0,
      category: 'Family',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Brother"?',
      options: [
        'Index finger touches forehead then down',
        'Hand on shoulder',
        'Two thumbs up',
        'Point to side'
      ],
      correctAnswerIndex: 0,
      category: 'Family',
    ),
  ];

  // ─── FOOD & DRINK CATEGORY ─────────────────────────────────
  static final List<QuizQuestion> foodQuestions = [
    QuizQuestion(
      question: 'What is the sign for "Water"?',
      options: [
        'W-shaped fingers tap chin',
        'Cupped hand to mouth',
        'Fingers wiggle like flowing',
        'Flat hand moves down throat'
      ],
      correctAnswerIndex: 0,
      category: 'Food & Drink',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Eat"?',
      options: [
        'Hand brings food to mouth',
        'Tapping stomach',
        'Rubbing belly',
        'Chewing motion'
      ],
      correctAnswerIndex: 0,
      category: 'Food & Drink',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Drink"?',
      options: [
        'Thumb to lips, tilt hand',
        'Cupped hand to mouth',
        'Swallowing motion',
        'Point to throat'
      ],
      correctAnswerIndex: 0,
      category: 'Food & Drink',
    ),
  ];

  // ─── EMOTIONS CATEGORY ─────────────────────────────────────
  static final List<QuizQuestion> emotionQuestions = [
    QuizQuestion(
      question: 'What is the sign for "Happy"?',
      options: [
        'Flat hands brush up chest twice',
        'Smiling face with hands',
        'Clapping hands',
        'Hands waving in air'
      ],
      correctAnswerIndex: 0,
      category: 'Emotions',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Sad"?',
      options: [
        'Hands move down face',
        'Head down with hands',
        'Wiping eyes',
        'Drooping shoulders'
      ],
      correctAnswerIndex: 0,
      category: 'Emotions',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Angry"?',
      options: [
        'Claw hands at chest then out',
        'Fists shaking',
        'Scrunched face',
        'Hands on hips'
      ],
      correctAnswerIndex: 0,
      category: 'Emotions',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Love"?',
      options: [
        'Crossed arms over chest',
        'Hands form heart shape',
        'Hand on heart',
        'Two fingers point to heart'
      ],
      correctAnswerIndex: 0,
      category: 'Emotions',
    ),
  ];

  // ─── TIME CATEGORY ─────────────────────────────────────────
  static final List<QuizQuestion> timeQuestions = [
    QuizQuestion(
      question: 'What is the sign for "Today"?',
      options: [
        'Two Y-hands tap together',
        'Point down then thumb up',
        'Hand circles in front',
        'Tap wrist twice'
      ],
      correctAnswerIndex: 0,
      category: 'Time',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Tomorrow"?',
      options: [
        'Thumb moves forward from chin',
        'Point forward then upward',
        'Hand circles forward',
        'Tap cheek then point forward'
      ],
      correctAnswerIndex: 0,
      category: 'Time',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Yesterday"?',
      options: [
        'Thumb moves back from chin',
        'Point backward',
        'Hand circles backward',
        'Tap shoulder then point back'
      ],
      correctAnswerIndex: 0,
      category: 'Time',
    ),
  ];

  // ─── COLORS CATEGORY ───────────────────────────────────────
  static final List<QuizQuestion> colorQuestions = [
    QuizQuestion(
      question: 'What is the sign for "Red"?',
      options: [
        'Index finger strokes lips',
        'Point to lips',
        'Make "R" handshape',
        'Wiggle fingers near chin'
      ],
      correctAnswerIndex: 0,
      category: 'Colors',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Blue"?',
      options: [
        'B-hand shakes at shoulder',
        'Point to sky',
        'Make "B" handshape',
        'Wave hand like water'
      ],
      correctAnswerIndex: 0,
      category: 'Colors',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Green"?',
      options: [
        'G-hand shakes at shoulder',
        'Point to grass',
        'Make "G" handshape',
        'Wave hand like leaves'
      ],
      correctAnswerIndex: 0,
      category: 'Colors',
    ),
  ];

  // ─── ANIMALS CATEGORY ──────────────────────────────────────
  static final List<QuizQuestion> animalQuestions = [
    QuizQuestion(
      question: 'What is the sign for "Dog"?',
      options: [
        'Pat thigh then snap fingers',
        'Panting tongue motion',
        'Make ears with hands',
        'Barking motion'
      ],
      correctAnswerIndex: 0,
      category: 'Animals',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Cat"?',
      options: [
        'Index fingers draw whiskers',
        'Petting motion',
        'Make ears with fingers',
        'Meowing motion'
      ],
      correctAnswerIndex: 0,
      category: 'Animals',
    ),
    
    QuizQuestion(
      question: 'What is the sign for "Bird"?',
      options: [
        'Thumb and index at mouth like beak',
        'Flapping arms',
        'Point to sky',
        'Chirping sound motion'
      ],
      correctAnswerIndex: 0,
      category: 'Animals',
    ),
  ];

  // ─── ALL QUESTIONS ─────────────────────────────────────────
  static List<QuizQuestion> get allQuestions {
    return [
      ...greetingQuestions,
      ...numberQuestions,
      ...familyQuestions,
      ...foodQuestions,
      ...emotionQuestions,
      ...timeQuestions,
      ...colorQuestions,
      ...animalQuestions,
    ];
  }

  // ─── HELPER METHODS ────────────────────────────────────────
  
  // Get random question for daily quiz
  static QuizQuestion getRandomQuestion() {
    final now = DateTime.now();
    final seed = now.millisecondsSinceEpoch;
    final randomIndex = seed % allQuestions.length;
    return allQuestions[randomIndex];
  }

  // Get questions by category
  static List<QuizQuestion> getQuestionsByCategory(String category) {
    switch (category) {
      case 'Greetings':
        return greetingQuestions;
      case 'Numbers':
        return numberQuestions;
      case 'Family':
        return familyQuestions;
      case 'Food & Drink':
        return foodQuestions;
      case 'Emotions':
        return emotionQuestions;
      case 'Time':
        return timeQuestions;
      case 'Colors':
        return colorQuestions;
      case 'Animals':
        return animalQuestions;
      default:
        return allQuestions;
    }
  }

  // Get all categories
  static List<String> get allCategories {
    return [
      'Greetings',
      'Numbers',
      'Family',
      'Food & Drink',
      'Emotions',
      'Time',
      'Colors',
      'Animals',
    ];
  }

  // Get question count by category
  static Map<String, int> get questionCountByCategory {
    return {
      'Greetings': greetingQuestions.length,
      'Numbers': numberQuestions.length,
      'Family': familyQuestions.length,
      'Food & Drink': foodQuestions.length,
      'Emotions': emotionQuestions.length,
      'Time': timeQuestions.length,
      'Colors': colorQuestions.length,
      'Animals': animalQuestions.length,
      'Total': allQuestions.length,
    };
  }
}