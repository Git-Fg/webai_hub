import 'package:flutter/material.dart';
import '../../../shared/models/ai_provider.dart';

class ProviderOptionsDialog extends StatelessWidget {
  final AIProvider provider;

  const ProviderOptionsDialog({
    Key? key,
    required this.provider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _getProviderIcon(provider),
                  color: Colors.deepPurpleAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Options - ${provider.displayName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Options List
            ..._buildOptions(context),

            const SizedBox(height: 20),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptions(BuildContext context) {
    return [
      // Model Selection
      _buildOptionTile(
        context,
        icon: Icons.model_training,
        title: 'Modèle IA',
        subtitle: 'Choisir le modèle à utiliser',
        onTap: () {
          Navigator.pop(context);
          _showComingSoon(context, 'Sélection de modèle');
        },
      ),

      const SizedBox(height: 12),

      // Temperature
      _buildOptionTile(
        context,
        icon: Icons.thermostat,
        title: 'Température',
        subtitle: 'Ajuster la créativité des réponses',
        onTap: () {
          Navigator.pop(context);
          _showComingSoon(context, 'Réglage température');
        },
      ),

      const SizedBox(height: 12),

      // Max Tokens
      _buildOptionTile(
        context,
        icon: Icons.text_fields,
        title: 'Tokens max',
        subtitle: 'Limiter la longueur des réponses',
        onTap: () {
          Navigator.pop(context);
          _showComingSoon(context, 'Limite tokens');
        },
      ),

      const SizedBox(height: 12),

      // System Prompt
      _buildOptionTile(
        context,
        icon: Icons.psychology,
        title: 'Prompt système',
        subtitle: 'Définir les instructions système',
        onTap: () {
          Navigator.pop(context);
          _showComingSoon(context, 'Configuration prompt système');
        },
      ),

      const SizedBox(height: 12),

      // Clear Conversation
      _buildOptionTile(
        context,
        icon: Icons.clear_all,
        title: 'Effacer conversation',
        subtitle: 'Supprimer l\'historique pour ce provider',
        onTap: () {
          Navigator.pop(context);
          _showComingSoon(context, 'Suppression conversation');
        },
        isDestructive: true,
      ),

      const SizedBox(height: 12),

      // Provider Info
      _buildOptionTile(
        context,
        icon: Icons.info,
        title: 'Informations',
        subtitle: 'Voir les détails du provider',
        onTap: () {
          Navigator.pop(context);
          _showProviderInfo(context);
        },
      ),
    ];
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red.shade400 : Colors.deepPurpleAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? Colors.red.shade400 : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Bientôt disponible!'),
        backgroundColor: Colors.deepPurpleAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showProviderInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getProviderIcon(provider),
                    color: Colors.deepPurpleAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'URL: ${provider.url}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Provider: ${provider.name.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.aistudio:
        return Icons.auto_awesome;
      case AIProvider.qwen:
        return Icons.cloud;
      case AIProvider.zai:
        return Icons.flash_on;
      case AIProvider.kimi:
        return Icons.document_scanner;
    }
  }
}