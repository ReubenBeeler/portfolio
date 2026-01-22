import 'package:flutter/material.dart';
import 'package:portfolio/widgets/skills_section.dart';
import 'package:portfolio/widgets/my_view.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl;
import 'package:web/web.dart' show window;

class ViewSkills extends StatelessView {
  ViewSkills({super.key}) : super(name: "Skills", icon: Icons.psychology_rounded);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.9,
      child: SkillsSection(
        // TODO add icons to skills!! Make this more visual-based
        // TODO add DevOps card with soft-skill mention like agility, etc. AND hard skills like Jenkins CI/CD
        skillCategories: [
          SkillCategory(
            title: 'DevOps',
            skills: [
              'Practices: Agile, Scrum',
              'Cloud Computing: AWS',
              'Containers: Dockers, Kubernetes, Helm',
              'CI/CD: OpenShift, Github Actions',
              'IaC: Tekton, Terraform, CloudFormation',
              'TDD/BDD: xUnit, nosetests, Behave',
              'Monitoring: Prometheus, CloudWatch',
              // Include/learn Elasticsearch & stacks like Elastic/ELK?
            ],
          ),
          SkillCategory(
            title: 'Programming Languages & Frameworks',
            skills: [
              'Python',
              [null, 'Flask, PyTorch, NumPy, SciPy, Matplotlib Pyplot'],
              'Java',
              [null, 'Android (e.g. fingerprint biometrics in ', 'XPressEntry', () => launchUrl(Uri.parse('https://telaeris.com/')), ')'],
              [null, 'Swing (see ', 'Chess', () => launchUrl(Uri.parse("https://github.com/ReubenBeeler/Chess")), ')'],
              [null, 'Spigot (see ', 'Compass', () => launchUrl(Uri.parse("https://github.com/ReubenBeeler/Compass")), ')'],
              'Dart',
              [null, 'Flutter (see ', 'this portfolio', () => launchUrl(Uri.parse('https://github.com/ReubenBeeler/portfolio')), ')'],
              'Objective-C',
              'C++',
              'Bash',
            ],
          ),
          SkillCategory(
            title: 'Scientific & High-Performance Computing',
            skills: [
              ['Parallel Scientific Computing (', 'UCSB CS 140', () => launchUrl(Uri.parse('https://catalog.ucsb.edu/courses/CMPSC%20140')), ')'],
              [
                null,
                'SPMD (see assignments: ',
                'MPI',
                () => launchUrl(Uri.parse('https://github.com/ReubenBeeler/CS140_PA1_MPI')),
                ', ',
                'OpenMP',
                ', ',
                'Pthreads',
                () => launchUrl(Uri.parse('https://github.com/ReubenBeeler/CS140_PA2b_Pthreads')),
                ', ',
                'CUDA',
                ')',
              ],
              ['Digital Electronics (', 'UCSB Physics 127BL', () => launchUrl(Uri.parse('https://catalog.ucsb.edu/courses/PHYS%20127BL')), ')'],
              [
                null,
                'FPGA design (see reports: ',
                'microprocessor',
                () => window.open("static/Reuben Beeler - Physics 127BL - Lab 11 Report.pdf", "_blank"),
                ', ',
                'RS-232 music player',
                () => window.open("static/Reuben Beeler - Physics 127BL - Lab 9 and 10 Report.pdf", "_blank"),
                ')',
              ],
              ['Quantum Computing (', 'UCSB Physics 150', () => launchUrl(Uri.parse('https://catalog.ucsb.edu/courses/PHYS%20150')), ')'],
              ['Computational Science (', 'UCSB CS 111', () => launchUrl(Uri.parse('https://catalog.ucsb.edu/courses/CMPSC%20111')), ')'],
              "Numerical Optimization (e.g. BFGS, QAOA)",
            ],
          ),
          SkillCategory(
            title: 'Databases',
            skills: [
              ['Relational Databases: PostgreSQL (see ', 'certificate', () => launchUrl(Uri.parse('https://coursera.org/share/d5d96126783b3a4c84e0985caf792533')), ')'], // TODO include scroll-to-certificate link
              ['NoSQL Databases: MongoDB (see ', 'certificate', () => launchUrl(Uri.parse('https://coursera.org/share/75086502db2319dfa765d124fa71d21f')), ')'], // TODO include scroll-to-certificate link
              'NLP, Sharding, ACID Transactions, Indexing, Aggregations',
            ],
          ),
          SkillCategory(
            title: 'Machine Learning & AI',
            skills: [
              // Text('Deep Learning Systems: Algorithms & Implementations (https://dlsyscourse.org/)'),
              ['Deep Learning (', 'CMU 11-785', () => launchUrl(Uri.parse('https://deeplearning.cs.cmu.edu/S25/index.html')), ' audit)'],
              ['Artifical Intelligence (', 'UCSB CS 165A', () => launchUrl(Uri.parse('https://catalog.ucsb.edu/courses/CMPSC%20165A')), ')'],
              ['Computer Vision (', 'UCSB CS 181', () => launchUrl(Uri.parse('https://catalog.ucsb.edu/courses/CMPSC%20181')), ')'],
            ],
          ),
          SkillCategory(
            title: 'Miscellaneous',
            skills: [
              ['Software Security (UCSB CS ', '177', () => launchUrl(Uri.parse('https://catalog.ucsb.edu/courses/CMPSC%20177')), ' & ', '279', () => launchUrl(Uri.parse('https://catalog.ucsb.edu/courses/CMPSC%20279')), ')'],
              [null, 'see Publications for VR hacking w/ IDA Pro rev. engineering'], // TODO include scroll-to-publication link
              'CAD (Fusion 360, see project Bike-Generator)',
              'Linux (CLI, pkg management, filesystem, perms)',
            ],
          ),
        ],
      ),
    );
  }
}
