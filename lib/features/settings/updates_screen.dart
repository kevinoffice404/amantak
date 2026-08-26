import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass.dart'; 

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({Key? key}) : super(key: key);

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  bool _isCheckingForUpdates = false;

  // دالة وهمية لمحاكاة عملية البحث عن تحديث جديد من الخادم
  void _checkForUpdates() {
    setState(() {
      _isCheckingForUpdates = true;
    });

    // محاكاة تحميل لمدة ثانيتين
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCheckingForUpdates = false;
        });
        
        // إظهار رسالة منبثقة زجاجية أو SnackBar أنيق
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'أنت تستخدم أحدث إصدار بالفعل!',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: Colors.green.withOpacity(0.8),
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.5)),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'التحديثات',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. البطاقة العلوية (الآن بتصميم زجاجي iOS 27)
            _buildGlassHeaderCard(),
            
            const SizedBox(height: 35),
            
            // 2. عنوان قسم سجل الإصدارات
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'سجل الإصدارات',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'كل ما تمت إضافته وتحسينه في النظام.',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Cairo',
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 3. بطاقة سجل الإصدارات الزجاجية
            GlassSurface(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  // رأس البطاقة (رقم الإصدار)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.6)),
                        ),
                        child: const Icon(Icons.verified_rounded, color: AppColors.primaryNavy, size: 28),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('الإصدار 1.0.0 (1)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.textDark)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: const Text('الحالي', style: TextStyle(fontFamily: 'Cairo', color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text('Release Candidate • 26/08/2026', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(height: 1, color: Colors.black12),
                  ),

                  // قائمة المميزات المضافة (تفتح وتغلق)
                  _buildGlassExpandableTile(
                    title: 'المميزات المضافة',
                    subtitle: '3 عناصر جديدة',
                    icon: Icons.auto_awesome_rounded,
                    iconColor: Colors.teal,
                    items: [
                      'نظام ذكي لحساب الرواتب بناءً على ساعات العمل الفعلية.',
                      'إصدار إيصالات رواتب PDF وتصديرها مع الخطوط العربية.',
                      'تطبيق النمط الزجاجي (iOS 27) الموحد على واجهات التطبيق.',
                    ],
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1, color: Colors.transparent),
                  ),

                  // قائمة الإصلاحات والتحسينات (تفتح وتغلق)
                  _buildGlassExpandableTile(
                    title: 'الإصلاحات والتحسينات',
                    subtitle: '3 تحسينات للأداء',
                    icon: Icons.build_circle_rounded,
                    iconColor: Colors.orange,
                    items: [
                      'حل مشكلة التقطيع في واجهة لوحة التحكم بعزل مؤقت الساعة.',
                      'إصلاح مشاكل تسريب الذاكرة (Memory Leaks) في القوائم المنبثقة.',
                      'تحسين سرعة استجابة قاعدة البيانات (SQLite) عند تسجيل الحضور.',
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 4. بطاقة المعلومات السفلية الزجاجية
            GlassSurface(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              color: Colors.blue.withOpacity(0.08),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20)
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'سجل التحديثات محفوظ محلياً لتتبع التطورات. زر التحقق يعمل حالياً في وضع عدم الاتصال (Offline) في هذه النسخة.',
                      style: TextStyle(fontFamily: 'Cairo', color: AppColors.textDark.withOpacity(0.8), fontSize: 13, height: 1.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==== 🚨 دالة بناء البطاقة العلوية الزجاجية (تحديث iOS 27) 🚨 ====
  Widget _buildGlassHeaderCard() {
    return GlassSurface(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(32), // حواف دائرية ناعمة جداً
      // إضافة لون خفيف للبطاقة لتمييزها عن الخلفية الرئيسية
      color: AppColors.primaryNavy.withOpacity(0.3), 
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // زر V1 الزجاجي
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Text(
                  'V1',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('نظام أمنتك', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                  Text('الإصدار الحالي 1.0.0 (1)', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                ],
              ),
              // أيقونة التحديث الزجاجية
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentGold.withOpacity(0.5)),
                ),
                child: const Icon(Icons.system_update_rounded, color: AppColors.accentGold, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'حافظ على نظامك محدثاً',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 12),
          const Text(
            'استكشف أحدث المميزات والتحسينات التي تمت إضافتها لتسهيل إدارتك اليومية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Cairo', height: 1.6, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 30),
          
          // 🚨 زر البحث عن تحديثات بالنمط الزجاجي 🚨
          InkWell(
            onTap: _isCheckingForUpdates ? null : _checkForUpdates,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1), // خلفية شبه شفافة
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5), // حدود زجاجية لامعة
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isCheckingForUpdates)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  else
                    const Icon(Icons.refresh_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    _isCheckingForUpdates ? 'جاري التحقق من الخادم...' : 'التحقق من وجود تحديثات',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==== دالة بناء القوائم المنسدلة بالنمط الزجاجي المتناسق ====
  Widget _buildGlassExpandableTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<String> items,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 12, right: 16, left: 16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: iconColor.withOpacity(0.3)),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy)),
        subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        iconColor: AppColors.primaryNavy,
        collapsedIconColor: Colors.grey,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6.0, left: 10.0),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.6), shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(item, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textDark, height: 1.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
