import '../models/offline_module.dart';
import 'package:flutter/material.dart';

final List<OfflineModule> allOfflineModules = [
  OfflineModule(
    id: '1',
    title: 'Full BIM Dictionary',
    description: 'The complete collection of all BIM signs.',
    zipFileName: 'Full_BIM_Dictionary.zip', 
    folderName: 'Full_BIM_Dictionary',      
    icon: Icons.book_outlined,
    includedVideos: [
      'Over 50+ signs', 
      'Alphabet Signs', 
      'Numeric Signs', 
      'Basic Greetings', 
      'Food & Drink Signs', 
      'Family & People Signs', 
      'Travel & Transport Signs'
    ],
  ),
  OfflineModule(
    id: '2',
    title: 'Numeric Signs',
    description: 'Signs for numbers 0-9.',
    zipFileName: 'numeric.zip',
    folderName: 'numeric',
    icon: Icons.pin,
    includedVideos: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
  ),
  OfflineModule(
    id: '3',
    title: 'Alphabet Signs',
    description: 'Signs for letters A-Z.',
    zipFileName: 'alphabet.zip',
    folderName: 'alphabet',
    icon: Icons.text_fields,
    includedVideos: [
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 
      'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 
      'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
    ],
  ),
  OfflineModule(
    id: '4',
    title: 'Basic Greetings',
    description: 'Essential signs for beginners & daily chat.',
    zipFileName: 'basic_greetings.zip', 
    folderName: 'basic_greetings',      
    icon: Icons.waving_hand_outlined, 
    includedVideos: [
      'Hello', 'I Love You', 'Morning', 'Night', 
      'No', 'Noon', 'Greet', 'Sorry', 'Thank You', 
      'Today', 'Yes'
    ],
  ),
  OfflineModule(
    id: '5',
    title: 'Food and Drinks',
    description: 'Signs for eating, restaurant, and common foods.',
    zipFileName: 'Food_Drink_Signs.zip',
    folderName: 'Food_Drink_Signs',
    icon: Icons.coffee_outlined,
    includedVideos: ['Bread', 'Drink', 'Eat', 'Hungry', 'Juice', 'Thirsty', 'Water'],
  ),
  OfflineModule(
    id: '6',
    title: 'Family & People',
    description: 'Signs for family members, friends, and relationships.',
    zipFileName: 'Family_People.zip',
    folderName: 'Family_People',
    icon: Icons.group_outlined,
    includedVideos: ['Father', 'Mother', 'Friend', 'Brother', 'Sister', 'I/Me'],
  ),
  OfflineModule(
    id: '7',
    title: 'Travel & Transport',
    description: 'Signs for travel, transport, and common actions.',
    zipFileName: 'Travel_Transport.zip',
    folderName: 'Travel_Transport',
    icon: Icons.travel_explore_outlined,
    includedVideos: ['Bus', 'Help', 'Hotel', 'How much?', 'Toilet'],
  ),
];