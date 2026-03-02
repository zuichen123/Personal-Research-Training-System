import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final resources = provider.resources;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习资料'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchResources(),
          ),
        ],
      ),
      body: provider.isLoading && resources.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : resources.isEmpty
              ? const Center(child: Text('未上传资料。'))
              : GridView.builder(
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
                      child: InkWell(
                        onTap: () {
                          // TODO: View or download resource
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.insert_drive_file, size: 48, color: Colors.blueGrey),
                              const SizedBox(height: 16),
                              Text(r.filename, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Text(r.category, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Upload resource
        },
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}
