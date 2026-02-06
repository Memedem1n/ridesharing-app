import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _selectedType = 'people';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  int _passengers = 1;

  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yolculuk Ara'),
      ),
      body: Column(
        children: [
          // Search Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                // From-To
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fromController,
                        decoration: const InputDecoration(
                          labelText: 'Nereden',
                          prefixIcon: Icon(Icons.trip_origin),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_vert),
                      onPressed: () {
                        final temp = _fromController.text;
                        _fromController.text = _toController.text;
                        _toController.text = temp;
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _toController,
                        decoration: const InputDecoration(
                          labelText: 'Nereye',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Date and Passengers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tarih',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Yolcu',
                          prefixIcon: Icon(Icons.person),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _passengers > 1 
                                  ? () => setState(() => _passengers--)
                                  : null,
                            ),
                            Text('$_passengers'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _passengers < 8
                                  ? () => setState(() => _passengers++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Type filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TypeChip(
                        label: 'İnsan',
                        icon: Icons.group,
                        selected: _selectedType == 'people',
                        onSelected: () => setState(() => _selectedType = 'people'),
                      ),
                      _TypeChip(
                        label: 'Hayvan',
                        icon: Icons.pets,
                        selected: _selectedType == 'pets',
                        onSelected: () => setState(() => _selectedType = 'pets'),
                      ),
                      _TypeChip(
                        label: 'Kargo',
                        icon: Icons.inventory_2,
                        selected: _selectedType == 'cargo',
                        onSelected: () => setState(() => _selectedType = 'cargo'),
                      ),
                      _TypeChip(
                        label: 'Gıda',
                        icon: Icons.restaurant,
                        selected: _selectedType == 'food',
                        onSelected: () => setState(() => _selectedType = 'food'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Results
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) => _TripCard(
                onTap: () => context.push('/trip/trip-$index'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final VoidCallback onTap;

  const _TripCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver info
              Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ahmet Y.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: AppColors.warning),
                          const Text(' 4.8 (32 değerlendirme)'),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '150 ₺',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Route
              Row(
                children: [
                  Column(
                    children: [
                      Icon(Icons.trip_origin, size: 16, color: AppColors.primary),
                      Container(
                        width: 2,
                        height: 24,
                        color: AppColors.border,
                      ),
                      Icon(Icons.location_on, size: 16, color: AppColors.secondary),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('İstanbul, Kadıköy', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),
                        Text('Ankara, Kızılay', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('08:00', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 20),
                      Text('12:30', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Tags
              Wrap(
                spacing: 8,
                children: [
                  _Tag(icon: Icons.airline_seat_recline_normal, label: '3 koltuk'),
                  _Tag(icon: Icons.ac_unit, label: 'Klima'),
                  _Tag(icon: Icons.smoke_free, label: 'Sigara yok'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
