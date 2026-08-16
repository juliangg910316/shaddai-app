import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/theme_colors.dart';
import '../../../core/widgets/app_widgets.dart';

/// Carta de servicios fija hasta definir de qué colección se lee.
class _Service {
  final String name;
  final String description;
  final String duration;
  final String price;

  const _Service(this.name, this.description, this.duration, this.price);
}

class _ServiceCategory {
  final String title;
  final List<_Service> services;

  const _ServiceCategory(this.title, this.services);
}

const _catalog = <_ServiceCategory>[
  _ServiceCategory('Manicure', [
    _Service(
      'Manicure Clásica',
      'Limpieza, exfoliación, masaje y esmaltado tradicional.',
      '45 min',
      '\$25',
    ),
    _Service(
      'Manicure Semipermanente',
      'Limpieza profunda y esmaltado de larga duración (Gel).',
      '60 min',
      '\$35',
    ),
  ]),
  _ServiceCategory('Acrílicas & Gel', [
    _Service(
      'Set Nuevo Acrílicas',
      'Uñas acrílicas con molde o tip, largo medio. Incluye esmaltado.',
      '90 min',
      '\$55',
    ),
    _Service(
      'Retoque Acrílico',
      'Relleno de crecimiento (hasta 3 semanas).',
      '60 min',
      '\$30',
    ),
  ]),
  _ServiceCategory('Pedicure', [
    _Service(
      'Pedicure Spa',
      'Limpieza profunda, remoción de callosidades, exfoliación, '
          'mascarilla y esmaltado.',
      '60 min',
      '\$40',
    ),
    _Service(
      'Jelly Pedicure',
      'Terapia de hidratación profunda con textura gelatinosa relajante.',
      '75 min',
      '\$50',
    ),
  ]),
];

class ServicesView extends StatelessWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bone,
      body: Column(
        children: [
          const _ServicesHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
              children: [
                for (final category in _catalog) ...[
                  SectionHeading(category.title, size: 22),
                  const SizedBox(height: 16),
                  for (final service in category.services) ...[
                    _ServiceCard(service: service),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 18,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: ThemeColors.white,
        border: Border(
          bottom: BorderSide(color: ThemeColors.gold.withValues(alpha: 0.30)),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Nuestros Servicios',
            style: AppText.serif(size: 24, color: ThemeColors.darkGreen),
          ),
          const SizedBox(height: 4),
          Text(
            "CARTA D'SHADDAI",
            style: AppText.eyebrow(
              size: 11,
              color: ThemeColors.gold,
              spacing: 2.6,
              weight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final _Service service;

  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  service.name,
                  style: AppText.serif(size: 19, color: ThemeColors.black),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                service.price,
                style: AppText.serif(
                  size: 19,
                  weight: FontWeight.w600,
                  color: ThemeColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            service.description,
            style: AppText.sans(
              size: 13,
              weight: FontWeight.w300,
              color: ThemeColors.olive,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: ThemeColors.olive,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    service.duration,
                    style: AppText.sans(
                      size: 12,
                      weight: FontWeight.w300,
                      color: ThemeColors.olive,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => context.go('/booking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColors.darkGreen,
                  foregroundColor: ThemeColors.gold,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'RESERVAR',
                  style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w500,
                    spacing: 1.2,
                    color: ThemeColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
