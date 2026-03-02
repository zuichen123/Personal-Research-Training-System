import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/resource.dart';
import '../providers/app_provider.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final resources = provider.resources;
    final loading = provider.isSectionLoading(DataSection.resources);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchResources(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchResources(force: true),
        child: _buildBody(provider, resources, loading),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload UI will be added next.')),
          );
        },
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Widget _buildBody(
    AppProvider provider,
    List<ResourceMaterial> resources,
    bool loading,
  ) {
    if (loading && resources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && resources.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('Load failed: ${provider.errorMessage}')),
        ],
      );
    }

    if (resources.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 96),
          Center(child: Text('No resources uploaded yet.')),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final r = resources[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.insert_drive_file,
                  size: 48,
                  color: Colors.blueGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  r.filename,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(r.category, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
