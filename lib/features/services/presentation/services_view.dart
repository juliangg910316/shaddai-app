import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';

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

List<_ServiceCategory> _catalog(AppLocalizations l10n) => [
  _ServiceCategory(l10n.categoryManicure, [
    _Service(
      l10n.serviceManicureClassicName,
      l10n.serviceManicureClassicDesc,
      l10n.duration45Min,
      '\$25',
    ),
    _Service(
      l10n.serviceManicureSemipermName,
      l10n.serviceManicureSemipermDesc,
      l10n.duration60Min,
      '\$35',
    ),
  ]),
  _ServiceCategory(l10n.categoryAcrylicGel, [
    _Service(
      l10n.serviceAcrylicSetName,
      l10n.serviceAcrylicSetDesc,
      l10n.duration90Min,
      '\$55',
    ),
    _Service(
      l10n.serviceAcrylicTouchupName,
      l10n.serviceAcrylicTouchupDesc,
      l10n.duration60Min,
      '\$30',
    ),
  ]),
  _ServiceCategory(l10n.categoryPedicure, [
    _Service(
      l10n.servicePedicureSpaName,
      l10n.servicePedicureSpaDesc,
      l10n.duration60Min,
      '\$40',
    ),
    _Service(
      l10n.serviceJellyPedicureName,
      l10n.serviceJellyPedicureDesc,
      l10n.duration75Min,
      '\$50',
    ),
  ]),
];

class ServicesView extends StatelessWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog(AppLocalizations.of(context)!);

    return Scaffold(
      body: Column(
        children: [
          const _ServicesHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
              children: [
                for (final category in catalog) ...[
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
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 18,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: brand.surface,
        border: Border(bottom: BorderSide(color: brand.goldHairlineSoft)),
      ),
      child: Column(
        children: [
          Text(
            l10n.ourServicesTitle,
            style: AppText.serif(size: 24, color: brand.inkStrong),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.servicesMenuEyebrow,
            style: AppText.eyebrow(
              size: 11,
              color: brand.accentText,
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
    final brand = context.brand;

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
                  style: AppText.serif(size: 19, color: brand.ink),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                service.price,
                style: AppText.serif(
                  size: 19,
                  weight: FontWeight.w600,
                  color: brand.accentText,
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
              color: brand.inkMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: brand.inkMuted),
                  const SizedBox(width: 6),
                  Text(
                    service.duration,
                    style: AppText.sans(
                      size: 12,
                      weight: FontWeight.w300,
                      color: brand.inkMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => context.go('/booking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand.brand,
                  foregroundColor: brand.onBrand,
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
                  AppLocalizations.of(context)!.bookAction,
                  style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w500,
                    spacing: 1.2,
                    color: brand.onBrand,
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
