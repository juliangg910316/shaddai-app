import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/theme_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '/l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';

/// Datos de catálogo fijos hasta definir de qué colección salen.
class _FeaturedService {
  final String name;
  final String duration;
  final String price;
  final String? imageUrl;

  const _FeaturedService(this.name, this.duration, this.price, [this.imageUrl]);
}

const _featuredServices = <_FeaturedService>[
  _FeaturedService(
    'Manicure Clásica',
    '45 min',
    '\$25',
    'https://images.unsplash.com/photo-1604654894610-df63bc536371?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
  ),
  _FeaturedService('Acrílicas Full', '90 min', '\$55'),
  _FeaturedService(
    'Pedicure Spa',
    '60 min',
    '\$40',
    'https://images.unsplash.com/photo-1516975080661-460d3fc3cfa5?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
  ),
  _FeaturedService('Retoque Acrílico', '60 min', '\$30'),
];

const _galleryPhotos = <String?>[
  'https://images.unsplash.com/photo-1595868846114-1e75ff41cb5f?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
  null,
  null,
  'https://images.unsplash.com/photo-1519014816548-bf5fe059e98b?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
];

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider).value;
    final firstName = currentUser?.displayName.split(' ').first ?? 'Invitada';

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: ThemeColors.bone,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 20,
            title: Text(
              l10n.appTitle,
              style: AppText.serif(
                size: 26,
                color: ThemeColors.gold,
                spacing: 0.5,
                height: 1,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: InitialsAvatar(
                  photoUrl: currentUser?.photoUrl,
                  name: currentUser?.displayName,
                  size: 34,
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Saludo
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${l10n.welcomeGreeting} '),
                        TextSpan(
                          text: firstName,
                          style: AppText.serif(
                            size: 22,
                            color: ThemeColors.darkGreen,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    style: AppText.serif(
                      size: 22,
                      weight: FontWeight.w400,
                      color: ThemeColors.black,
                      height: 1.2,
                    ),
                  ),
                ),

                // Hero
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _HeroCard(
                    ctaLabel: l10n.bookAppointment.toUpperCase(),
                    onTap: () => context.go('/booking'),
                  ),
                ),

                // Servicios populares
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                  child: SectionHeadingWithAction(
                    'Servicios populares',
                    actionLabel: 'VER TODO',
                    onAction: () => context.go('/services'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 160,
                        ),
                    itemCount: _featuredServices.length,
                    itemBuilder: (context, index) => _ServiceTile(
                      service: _featuredServices[index],
                      onTap: () => context.go('/booking'),
                    ),
                  ),
                ),

                // Nuestros trabajos
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                  child: Text(
                    'Nuestros trabajos',
                    style: AppText.serif(
                      size: 21,
                      color: ThemeColors.darkGreen,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 96,
                        ),
                    itemCount: _galleryPhotos.length,
                    itemBuilder: (context, index) {
                      final url = _galleryPhotos[index];
                      final tint = index.isEven
                          ? ThemeColors.sand
                          : ThemeColors.sandDark;
                      if (url == null) {
                        return PhotoPlaceholder(
                          label: 'FOTO DEL SALÓN',
                          color: tint,
                        );
                      }
                      return NetworkPhoto(
                        url: url,
                        placeholderLabel: 'FOTO DEL SALÓN',
                        placeholderColor: tint,
                      );
                    },
                  ),
                ),

                // Ubicación
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 30, 20, 14),
                  child: SectionHeading('Encuéntranos'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FlatCard(
                    padding: const EdgeInsets.all(18),
                    borderColor: ThemeColors.goldHairlineSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: ThemeColors.bone,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: ThemeColors.darkGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "D'Shaddai Studio",
                                    style: AppText.serif(
                                      size: 17,
                                      color: ThemeColors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Av. Principal 123, Centro',
                                    style: AppText.sans(
                                      size: 13,
                                      weight: FontWeight.w300,
                                      color: ThemeColors.olive,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const NetworkPhoto(
                          url:
                              'https://images.unsplash.com/photo-1524661135-423995f22d0b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                          height: 140,
                          radius: 12,
                          placeholderLabel: 'MAPA',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String ctaLabel;
  final VoidCallback onTap;

  const _HeroCard({required this.ctaLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 250,
        color: ThemeColors.darkGreen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.5,
              child: Image.network(
                'https://images.unsplash.com/photo-1522337660859-02fbefca4702?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ThemeColors.black.withValues(alpha: 0.10),
                    ThemeColors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "D'Shaddai\nNail Salon",
                    style: AppText.serif(
                      size: 34,
                      color: ThemeColors.white,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cuidado de lujo para tus uñas',
                    style: AppText.sans(
                      size: 14,
                      weight: FontWeight.w300,
                      color: ThemeColors.bone,
                      spacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GoldPillButton(label: ctaLabel, onPressed: onTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final _FeaturedService service;
  final VoidCallback onTap;

  const _ServiceTile({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ThemeColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.goldHairlineSoft),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 88,
              width: double.infinity,
              child: service.imageUrl == null
                  ? const PhotoPlaceholder(radius: 0)
                  : NetworkPhoto(
                      url: service.imageUrl!,
                      height: 88,
                      radius: 0,
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.serif(
                        size: 16,
                        color: ThemeColors.darkGreen,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          service.duration,
                          style: AppText.sans(
                            size: 11,
                            weight: FontWeight.w300,
                            color: ThemeColors.olive,
                          ),
                        ),
                        Text(
                          service.price,
                          style: AppText.serif(
                            size: 16,
                            color: ThemeColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
