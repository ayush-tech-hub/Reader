import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/router/app_router.dart';

/// Built-in document templates shown as a gallery. Tapping a template
/// creates a copy in the documents directory and opens it in the
/// Markdown editor.
class DocumentTemplatesScreen extends StatelessWidget {
  const DocumentTemplatesScreen({super.key});

  static const _templates = <_Template>[
    _Template(
      name: 'Meeting Notes',
      icon: Icons.groups_outlined,
      description: 'Agenda, attendees, action items',
      content: '''# Meeting Notes

**Date:** <!-- date -->
**Attendees:**
-

## Agenda
1.

## Discussion

## Action Items
| Task | Owner | Due |
|------|-------|-----|
|      |       |     |

## Next Meeting
**Date:**
''',
    ),
    _Template(
      name: 'Research Paper',
      icon: Icons.science_outlined,
      description: 'Abstract, introduction, methodology, conclusion',
      content: '''# Title

**Authors:**
**Date:** <!-- date -->

## Abstract

## 1. Introduction

## 2. Related Work

## 3. Methodology

## 4. Results

## 5. Discussion

## 6. Conclusion

## References
1.
''',
    ),
    _Template(
      name: 'Project Brief',
      icon: Icons.folder_special_outlined,
      description: 'Goals, scope, timeline, stakeholders',
      content: '''# Project Brief

## Overview

**Project name:**
**Owner:**
**Start date:**
**Target delivery:**

## Problem Statement

## Goals & Success Criteria
- [ ]
- [ ]

## Scope
### In scope
-

### Out of scope
-

## Timeline
| Milestone | Date |
|-----------|------|
|           |      |

## Stakeholders
| Name | Role |
|------|------|
|      |      |

## Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
|      |           |        |            |
''',
    ),
    _Template(
      name: 'Daily Journal',
      icon: Icons.book_outlined,
      description: 'Reflection, tasks, gratitude',
      content: '''# <!-- date -->

## Morning Intentions
Three things I want to accomplish today:
1.
2.
3.

## Reflection

## Grateful for
-

## Tasks
- [ ]
- [ ]
- [ ]

## Evening Notes
''',
    ),
    _Template(
      name: 'Cover Letter',
      icon: Icons.mail_outline,
      description: 'Professional job application letter',
      content: '''Your Name
Your Address
City, Country
Email | Phone

<!-- date -->

Hiring Manager Name
Company Name
Company Address

---

Dear <!-- Name -->:

**Opening paragraph** — State the position and why you are excited about this role.

**Middle paragraph** — Highlight two or three achievements that match the job requirements. Use concrete numbers where possible.

**Closing paragraph** — Express enthusiasm, mention you would welcome an interview, and thank the reader for their time.

Sincerely,

Your Name
''',
    ),
    _Template(
      name: 'Bug Report',
      icon: Icons.bug_report_outlined,
      description: 'Reproduction steps, environment, expected vs actual',
      content: '''# Bug Report

## Summary


## Environment
- **OS:**
- **App version:**
- **Device:**

## Steps to Reproduce
1.
2.
3.

## Expected Behaviour


## Actual Behaviour


## Screenshots / Logs

<!-- attach screenshots or paste log output here -->

## Additional Context

''',
    ),
    _Template(
      name: 'Blank Document',
      icon: Icons.insert_drive_file_outlined,
      description: 'Start with an empty canvas',
      content: '# New Document\n\n',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New from Template')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisExtent: 130,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _templates.length,
        itemBuilder: (context, i) => _TemplateCard(template: _templates[i]),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final _Template template;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(template.icon, color: scheme.primary, size: 28),
              const SizedBox(height: 8),
              Text(template.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                template.description,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = _safeName(template.name);
      var file = File('${dir.path}/$name.md');
      // Avoid overwriting an existing file by appending a counter.
      var counter = 1;
      while (file.existsSync()) {
        file = File('${dir.path}/${name}_$counter.md');
        counter++;
      }
      // Replace the date placeholder with today's date.
      final today =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      final content = template.content.replaceAll('<!-- date -->', today);
      await file.writeAsString(content);

      if (context.mounted) {
        context.push(
          '${Routes.markdownEditor}?path=${Uri.encodeComponent(file.path)}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create file: $e')),
        );
      }
    }
  }

  static String _safeName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

class _Template {
  const _Template({
    required this.name,
    required this.icon,
    required this.description,
    required this.content,
  });
  final String name;
  final IconData icon;
  final String description;
  final String content;
}
