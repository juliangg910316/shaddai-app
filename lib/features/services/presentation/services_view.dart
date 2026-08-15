import 'package:flutter/material.dart';
import '../../../core/constants/theme_colors.dart';
import 'package:go_router/go_router.dart';

class ServicesView extends StatelessWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bone,
      appBar: AppBar(
        title: const Text('Nuestros Servicios'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildCategoryTitle('Manicure'),
          _buildServiceItem(
            context,
            'Manicure Clásica',
            'Limpieza, exfoliación, masaje y esmaltado tradicional.',
            '45 min',
            '\$25',
          ),
          _buildServiceItem(
            context,
            'Manicure Semipermanente',
            'Limpieza profunda y esmaltado de larga duración (Gel).',
            '60 min',
            '\$35',
          ),
          const SizedBox(height: 24),
          _buildCategoryTitle('Acrílicas & Gel'),
          _buildServiceItem(
            context,
            'Set Nuevo Acrílicas',
            'Uñas acrílicas con molde o tip, largo medio. Incluye esmaltado.',
            '90 min',
            '\$55',
          ),
          _buildServiceItem(
            context,
            'Retoque Acrílico',
            'Relleno de crecimiento (hasta 3 semanas).',
            '60 min',
            '\$30',
          ),
          const SizedBox(height: 24),
          _buildCategoryTitle('Pedicure'),
          _buildServiceItem(
            context,
            'Pedicure Spa',
            'Limpieza profunda, remoción de callosidades, exfoliación, mascarilla y esmaltado.',
            '60 min',
            '\$40',
          ),
          _buildServiceItem(
            context,
            'Jelly Pedicure',
            'Terapia de hidratación profunda con textura gelatinosa relajante.',
            '75 min',
            '\$50',
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCategoryTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: ThemeColors.darkGreen,
          fontFamily: 'serif',
        ),
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, String name, String description, String duration, String price) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.black,
                    ),
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: ThemeColors.olive),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: ThemeColors.olive),
                    const SizedBox(width: 4),
                    Text(duration, style: const TextStyle(color: ThemeColors.olive)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to booking
                    context.go('/booking');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColors.darkGreen,
                    foregroundColor: ThemeColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text('Reservar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
