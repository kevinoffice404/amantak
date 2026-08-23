import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardCard({
    super.key, 
    required this.title, 
    required this.icon, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      // تم إزالة الـ Padding من هنا ليأخذ InkWell مساحة الزجاج بالكامل
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20), // نفس انحناء الكارت الزجاجي لكي لا يخرج التموج عن الحواف
        child: Padding(
          padding: const EdgeInsets.all(14), // تم نقل الـ Padding للداخل هنا
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(.7)),
                ),
                child: Icon(icon, size: 30, color: AppColors.primaryBlue),
              ),
              const SizedBox(height: 10),
              Text(
                title, 
                textAlign: TextAlign.center, 
                style: const TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.w700, 
                  color: AppColors.textDark, 
                  fontFamily: 'Cairo'
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
