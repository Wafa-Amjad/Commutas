import 'dart:async';

class VehicleService {
  Future<Map<String, String>> fetchVehicleDetails(String regNo) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 600));

    final Map<String, Map<String, String>> predefinedVehicles = {
      'ICT-1234': {
        'bus_reg_no': 'ICT-1234',
        'driver_name': 'Muhammad Tariq',
        'seat_capacity': '40 seats',
      },
      'ABT-4471': {
        'bus_reg_no': 'ABT-4471',
        'driver_name': 'Zahid Khan',
        'seat_capacity': '36 seats',
      },
      'LE-12-3456': {
        'bus_reg_no': 'LE-12-3456',
        'driver_name': 'Sajid Mehmood',
        'seat_capacity': '52 seats',
      },
      'A-1': {
        'bus_reg_no': 'A-1',
        'driver_name': 'Ali Raza',
        'seat_capacity': '15 seats',
      },
      '1': {
        'bus_reg_no': '1',
        'driver_name': 'Muhammad Asif',
        'seat_capacity': '30 seats',
      },
    };

    final upperReg = regNo.trim().toUpperCase();
    if (predefinedVehicles.containsKey(upperReg)) {
      return predefinedVehicles[upperReg]!;
    }

    // Default fallback if registration number is not in predefined list
    return {
      'bus_reg_no': upperReg,
      'driver_name': 'Muhammad Tariq (Default)',
      'seat_capacity': '40 seats (Default)',
    };
  }

  Future<List<Map<String, String>>> fetchAssignedRoutes(String regNo) async {
    // Simulate database delay
    await Future.delayed(const Duration(milliseconds: 500));

    final Map<String, List<Map<String, String>>> schedules = {
      'ICT-1234': [
        {'session': 'Morning', 'route': 'Route 01 (PMA Road)', 'path': 'Main Campus → PMA Road → Dhamtor', 'timing': '08:00 AM - 08:40 AM'},
        {'session': 'Evening', 'route': 'Route 01 (PMA Road)', 'path': 'Dhamtor → PMA Road → Main Campus', 'timing': '01:30 PM - 02:10 PM'},
      ],
      'ABT-4471': [
        {'session': 'Morning', 'route': 'Route 02 (Fawara Chowk)', 'path': 'Main Campus → Fawara Chowk → Dhamtor', 'timing': '08:00 AM - 08:40 AM'},
        {'session': 'Evening', 'route': 'Route 02 (Fawara Chowk)', 'path': 'Dhamtor → Fawara Chowk → Main Campus', 'timing': '04:30 PM - 05:10 PM'},
      ],
      'LE-12-3456': [
        {'session': 'Morning', 'route': 'Route 03 (Murree Road)', 'path': 'Main Campus → Murree Road → Dhamtor', 'timing': '08:00 AM - 08:40 AM'},
        {'session': 'Evening', 'route': 'Route 03 (Murree Road)', 'path': 'Dhamtor → Murree Road → Main Campus', 'timing': '01:30 PM - 02:10 PM'},
      ],
      'A-1': [
        {'session': 'Morning', 'route': 'Route 01 (PMA Road)', 'path': 'Main Campus → PMA Road → Dhamtor', 'timing': '08:00 AM - 08:40 AM'},
      ],
      '1': [
        {'session': 'Morning', 'route': 'Route 02 (Fawara Chowk)', 'path': 'Main Campus → Fawara Chowk → Dhamtor', 'timing': '08:00 AM - 08:40 AM'},
      ],
    };

    final upperReg = regNo.trim().toUpperCase();
    if (schedules.containsKey(upperReg)) {
      return schedules[upperReg]!;
    }

    // Default fallback
    return [
      {'session': 'Morning', 'route': 'Route 01 (PMA Road)', 'path': 'Main Campus → PMA Road → Dhamtor', 'timing': '08:00 AM - 08:40 AM'},
      {'session': 'Evening', 'route': 'Route 01 (PMA Road)', 'path': 'Dhamtor → PMA Road → Main Campus', 'timing': '01:30 PM - 02:10 PM'},
    ];
  }
}
