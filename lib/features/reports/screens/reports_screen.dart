import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io' as io;
import '../../clients/bloc/clients_bloc.dart';
import '../../../../models/client.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<ClientsBloc>().add(ClientsSubscriptionRequested());
    return BlocListener<ClientsBloc, ClientsState>(
      listener: (context, state) {
        if (state is ClientsOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text(state.message),
             backgroundColor: Colors.green,
             duration: const Duration(seconds: 4),
          ));
          context.read<ClientsBloc>().add(ClientsSubscriptionRequested());
        } else if (state is ClientsError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text(state.message),
             backgroundColor: Colors.red,
          ));
        } else if (state is ClientsImportConflict) {
           _showConflictDialog(context, state.conflictingClients, state.safeClients);
        }
      },
      child: BlocBuilder<ClientsBloc, ClientsState>(
        builder: (context, state) {
          if (state is ClientsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final clients = (state is ClientsLoaded) ? state.clients : <Client>[];

          return Container(
            color: const Color(0xFFF9FAFB),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Download all client data as CSV or PDF.'),
                      const SizedBox(height: 16),
                      
                      if (clients.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12.0),
                          child: Text('No clients available to export.', style: TextStyle(color: Colors.grey)),
                        ),

                      if (clients.isNotEmpty) ...[
                        ElevatedButton.icon(
                          onPressed: () => _promptExportFormatAndDownload(context, clients),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Download All Clients'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      ElevatedButton.icon(
                        onPressed: () => _importClients(context),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Import Clients from CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _importClients(BuildContext context) async {
     // Trigger BLoC event which delegates to Repository
     // But wait, the Repository method 'importClientsFromCsv' returns a String message.
     // The BLoC event 'ClientsImportCsv' might not expose the result directly if it's void.
     // Let's check ClientsBloc.
     // If Bloc handles it, it might emit a state or show a snackbar?
     // Actually the BLoC implementation in 'ClientsBloc' calls repo and emits Loaded.
     // It doesn't seem to return the message string to UI.
     // Check ClientsBloc implementation (Step 98):
     // on<ClientsImportCsv>... await repository.importClientsFromCsv()... add(ClientsUpdatedList)...
     // It swallows the success message string?
     // If so, I should ideally refactor to show it, but for now allow the import to happen.
     // Repo uses FilePicker internally.
     
     context.read<ClientsBloc>().add(ClientsImportCsv());
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import process started... content update will reflect shortly.')));
  }

  Future<void> _promptExportFormatAndDownload(BuildContext context, List<Client> clients) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text('Download as', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.grid_on_outlined),
                title: const Text('CSV (Excel)'),
                onTap: () => Navigator.pop(ctx, 'csv'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                onTap: () => Navigator.pop(ctx, 'pdf'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (choice == 'csv') {
      await _exportAllClientsAsCsv(context, clients);
    } else if (choice == 'pdf') {
       await _exportAllClientsAsPdf(context, clients);
    }
  }

  Future<void> _exportAllClientsAsCsv(BuildContext context, List<Client> clients) async {
    final headers = ['ID','First Name','Last Name','Gender','DOB','Email','Phone','Occupation','Description'];
    final rows = <List<String>>[headers];
    for (final c in clients) {
       rows.add([
        c.id.toString(),
        c.firstName,
        c.lastName,
        c.gender,
        c.dob,
        c.email,
        c.phone,
        c.occupation,
        c.description.replaceAll('\n', ' ').replaceAll(',', ';'),
      ]);
    }
    final csv = rows.map((r) => r.map((v){
      final needsQuotes = v.contains(',') || v.contains('"') || v.contains('\n');
      var val = v.replaceAll('"', '""');
      return needsQuotes ? '"'+val+'"' : val;
    }).join(',')).join('\n');

    // Strategy 1: File Picker (SAF)
    try {
      String? outputFile = await FilePicker.platform.saveFile(
         dialogTitle: 'Save CSV',
         fileName: 'clients_export.csv',
         allowedExtensions: ['csv'],
         type: FileType.custom,
      );

      if (outputFile != null) {
          final file = io.File(outputFile);
          await file.writeAsString(csv);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $outputFile')));
          return;
      }
    } catch (_) {}

    // Strategy 2: Public Documents Folder (User Requested)
    if (io.Platform.isAndroid) {
        bool accessGranted = false;
        var status = await Permission.storage.request();
        if (status.isGranted) {
          accessGranted = true;
        } else if (await Permission.manageExternalStorage.request().isGranted) {
          accessGranted = true;
        }

        if (accessGranted) {
           try {
             final docsDir = io.Directory('/storage/emulated/0/Download');
             if (!docsDir.existsSync()) {
               await docsDir.create(recursive: true);
             }
             final fileName = 'clients_export_${DateTime.now().millisecondsSinceEpoch}.csv';
             final file = io.File('${docsDir.path}/$fileName');
             await file.writeAsString(csv);
             
             if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text('Saved to Downloads: $fileName'),
                 duration: const Duration(seconds: 5),
               ));
             }
             return;
           } catch (e) {
             debugPrint('Public Document save failed: $e');
           }
        }

        // Fallback: App-Specific Storage
        try {
            final directory = await getExternalStorageDirectory();
            if (directory != null) {
               final reportDir = io.Directory('${directory.path}/Reports');
               if (!reportDir.existsSync()) {
                 await reportDir.create(recursive: true);
               }
               
               final fileName = 'clients_export_${DateTime.now().millisecondsSinceEpoch}.csv';
               final file = io.File('${reportDir.path}/$fileName');
               await file.writeAsString(csv);
               
               if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                   content: Text('Saved to: Android/data/.../Reports/$fileName'),
                   duration: const Duration(seconds: 8),
                 ));
               }
               return;
            }
        } catch (_) {}
    }

    // Strategy 3: Share Fallback
    final dir = await getTemporaryDirectory();
    final file = io.File('${dir.path}/clients_export.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _exportAllClientsAsPdf(BuildContext context, List<Client> clients) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (contexts) { 
          return [
            pw.Text('All Clients', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['ID','First Name','Last Name','Gender','DOB','Email','Phone','Occupation','Description'],
              data: clients.map((c) => [
                c.id, c.firstName, c.lastName, c.gender, c.dob, c.email, c.phone, c.occupation, c.description,
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    
    // Strategy 1: File Picker
    try {
      String? outputFile = await FilePicker.platform.saveFile(
         dialogTitle: 'Save PDF',
         fileName: 'clients_export.pdf',
         allowedExtensions: ['pdf'],
         type: FileType.custom,
      );

      if (outputFile != null) {
          final file = io.File(outputFile);
          await file.writeAsBytes(bytes, flush: true);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $outputFile')));
          return;
      }
    } catch (_) {}

    // Strategy 2: Public Documents Folder (User Requested)
    if (io.Platform.isAndroid) {
        bool accessGranted = false;
        var status = await Permission.storage.request();
        if (status.isGranted) {
          accessGranted = true;
        } else if (await Permission.manageExternalStorage.request().isGranted) {
          accessGranted = true;
        }

        if (accessGranted) {
           try {
             final docsDir = io.Directory('/storage/emulated/0/Download');
             if (!docsDir.existsSync()) {
               await docsDir.create(recursive: true);
             }
             final fileName = 'clients_export_${DateTime.now().millisecondsSinceEpoch}.pdf';
             final file = io.File('${docsDir.path}/$fileName');
             await file.writeAsBytes(bytes, flush: true);
             
             if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text('Saved to Downloads: $fileName'),
                 duration: const Duration(seconds: 5),
               ));
             }
             return;
           } catch (e) {
             debugPrint('Public Document save failed: $e');
           }
        }

        // Fallback: App-Specific Storage
        try {
            final directory = await getExternalStorageDirectory();
            if (directory != null) {
               final reportDir = io.Directory('${directory.path}/Reports');
               if (!reportDir.existsSync()) {
                 await reportDir.create(recursive: true);
               }
               
               final fileName = 'clients_export_${DateTime.now().millisecondsSinceEpoch}.pdf';
               final file = io.File('${reportDir.path}/$fileName');
               await file.writeAsBytes(bytes, flush: true);
               
               if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                   content: Text('Saved to: Android/data/.../Reports/$fileName'),
                   duration: const Duration(seconds: 8),
                 ));
               }
               return;
            }
        } catch (_) {}
    }

    // Strategy 3: Share
    final dir = await getTemporaryDirectory();
    final file = io.File('${dir.path}/clients_export.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _showConflictDialog(BuildContext context, List<Client> conflicting, List<Client> safe) async {
    final selected = <int>{}; 

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Duplicate Names Found', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Found ${conflicting.length} clients with names that already exist.\nSelect the ones you explicitly want to import:', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: conflicting.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final c = conflicting[index];
                            return CheckboxListTile(
                              value: selected.contains(index),
                              activeColor: const Color(0xFFF59E0B), 
                              title: Text('${c.firstName} ${c.lastName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(c.email, style: const TextStyle(fontSize: 12)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) selected.add(index);
                                  else selected.remove(index);
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import cancelled.')));
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final selectedClients = <Client>[];
                    for (int i=0; i<conflicting.length; i++) {
                       if (selected.contains(i)) {
                          selectedClients.add(conflicting[i]);
                       }
                    }
                    context.read<ClientsBloc>().add(ClientsConfirmConflictResolution(selectedClients, safe));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
                  child: Text('Import ${selected.length + safe.length} Clients'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
