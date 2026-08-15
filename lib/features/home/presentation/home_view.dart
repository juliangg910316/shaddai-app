import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/theme_colors.dart';
import 'package:go_router/go_router.dart';
import '/l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      body: CustomScrollView(
        slivers: [
          // AppBar / Header
          SliverAppBar(
            backgroundColor: ThemeColors.bone,
            pinned: true,
            elevation: 0,
            title: Text(
              l10n.appTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ThemeColors.gold,
                fontFamily: 'serif',
              ),
            ),
            actions: [
              if (currentUser?.photoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(currentUser!.photoUrl!),
                    radius: 18,
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Icon(
                    Icons.account_circle,
                    color: ThemeColors.darkGreen,
                    size: 32,
                  ),
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Message
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    l10n.welcomeBack(
                      currentUser?.displayName?.split(' ').first ?? "Invitada",
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: ThemeColors.black,
                    ),
                  ),
                ),

                // Hero Section
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: ThemeColors.white,
                    borderRadius: BorderRadius.circular(24),
                    image: DecorationImage(
                      image: const NetworkImage(
                        'https://images.unsplash.com/photo-1522337660859-02fbefca4702?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                      ),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.5),
                        BlendMode.darken,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeColors.darkGreen.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "D'Shaddai\nNail Salon",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: ThemeColors.white,
                          fontFamily: 'serif',
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Cuidado de Lujo para tus Uñas",
                        style: TextStyle(fontSize: 16, color: ThemeColors.bone),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/booking'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: ThemeColors.gold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            l10n.bookAppointment.toUpperCase(),
                            style: const TextStyle(
                              color: ThemeColors.darkGreen,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Featured Services Section
                _buildSectionTitle('Servicios Populares'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildServiceCard(
                        'Manicure Clásica',
                        '45 min',
                        '\$25',
                        'https://images.unsplash.com/photo-1604654894610-df63bc536371?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
                      ),
                      _buildServiceCard(
                        'Acrílicas Full',
                        '90 min',
                        '\$55',
                        'https://images.unsplash.com/photo-1519014816548-bf5fe059e98b?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
                      ),
                      _buildServiceCard(
                        'Pedicure Spa',
                        '60 min',
                        '\$40',
                        'https://images.unsplash.com/photo-1516975080661-460d3fc3cfa5?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Gallery Section
                _buildSectionTitle('Nuestros Trabajos'),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildGalleryImage(
                        'https://images.unsplash.com/photo-1595868846114-1e75ff41cb5f?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
                      ),
                      _buildGalleryImage(
                        'https://images.unsplash.com/photo-1512496015851-a1cbf89a09c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
                      ),
                      _buildGalleryImage(
                        'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
                      ),
                      _buildGalleryImage(
                        'https://images.unsplash.com/photo-1519014816548-bf5fe059e98b?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Location & Contact
                _buildSectionTitle('Encuéntranos'),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ThemeColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThemeColors.gold.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ThemeColors.bone,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: ThemeColors.darkGreen,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'D\'Shaddai Studio',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Av. Principal 123, Centro',
                                  style: TextStyle(color: ThemeColors.olive),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[300],
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://images.unsplash.com/photo-1524661135-423995f22d0b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                            ), // Placeholder for Map
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColors.darkGreen.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Ver en el Mapa',
                              style: TextStyle(
                                color: ThemeColors.gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.darkGreen,
              fontFamily: 'serif',
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: ThemeColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    String title,
    String duration,
    String price,
    String imageUrl,
  ) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: ThemeColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.darkGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    color: ThemeColors.olive,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.gold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(imageUrl, fit: BoxFit.cover),
    );
  }
}
