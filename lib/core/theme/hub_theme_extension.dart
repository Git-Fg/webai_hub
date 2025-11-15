import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:flutter/material.dart';

/// WHY: This ThemeExtension centralizes all custom UI styles for the AI Hybrid Hub.
/// It replaces scattered hardcoded styles with a semantic, maintainable design system
/// that supports animated theme transitions via proper lerp implementation.
@immutable
class HubThemeExtension extends ThemeExtension<HubThemeExtension> {
  const HubThemeExtension({
    // Chat Bubble Styles
    this.incomingBubbleDecoration,
    this.outgoingBubbleDecoration,
    this.incomingBubbleEditingDecoration,
    this.outgoingBubbleEditingDecoration,
    this.incomingBubbleTextStyle,
    this.outgoingBubbleTextStyle,
    this.incomingBubbleAvatarColor,
    this.outgoingBubbleAvatarColor,
    this.incomingBubbleIconColor,
    this.outgoingBubbleIconColor,
    this.editCancelIconColor,
    this.editSaveIconColor,
    
    // Message Status Styles
    this.messageSendingColor,
    this.messageErrorColor,
    
    // Input Bar Styles
    this.inputBarDecoration,
    this.inputFieldDecoration,
    this.sendButtonColor,
    this.sendButtonIconColor,
    
    // Card and Container Styles
    this.cardDecoration,
    this.panelDecoration,
    
    // Action Button Colors
    this.primaryActionButtonColor,
    this.secondaryActionButtonColor,
    this.successActionButtonColor,
    this.warningActionButtonColor,
    this.actionButtonTextColor,
    
    // Tab Bar Colors
    this.tabBarSelectedColor,
    this.tabBarUnselectedColor,
    this.tabBarIndicatorColor,
    
    // Overlay Colors
    this.overlayHeaderColor,
    this.overlayIconColor,
    
    // General UI Colors
    this.surfaceColor,
    this.onSurfaceColor,
    this.dividerColor,
  });

  // ============================================================================
  // Chat Bubble Properties
  // ============================================================================
  
  final BoxDecoration? incomingBubbleDecoration;
  final BoxDecoration? outgoingBubbleDecoration;
  final BoxDecoration? incomingBubbleEditingDecoration;
  final BoxDecoration? outgoingBubbleEditingDecoration;
  
  final TextStyle? incomingBubbleTextStyle;
  final TextStyle? outgoingBubbleTextStyle;
  
  final Color? incomingBubbleAvatarColor;
  final Color? outgoingBubbleAvatarColor;
  final Color? incomingBubbleIconColor;
  final Color? outgoingBubbleIconColor;
  
  final Color? editCancelIconColor;
  final Color? editSaveIconColor;
  
  // ============================================================================
  // Message Status Properties
  // ============================================================================
  
  final Color? messageSendingColor;
  final Color? messageErrorColor;
  
  // ============================================================================
  // Input Bar Properties
  // ============================================================================
  
  final BoxDecoration? inputBarDecoration;
  final BoxDecoration? inputFieldDecoration;
  final Color? sendButtonColor;
  final Color? sendButtonIconColor;
  
  // ============================================================================
  // Card and Container Properties
  // ============================================================================
  
  final BoxDecoration? cardDecoration;
  final BoxDecoration? panelDecoration;
  
  // ============================================================================
  // Action Button Properties
  // ============================================================================
  
  final Color? primaryActionButtonColor;
  final Color? secondaryActionButtonColor;
  final Color? successActionButtonColor;
  final Color? warningActionButtonColor;
  final Color? actionButtonTextColor;
  
  // ============================================================================
  // Tab Bar Properties
  // ============================================================================
  
  final Color? tabBarSelectedColor;
  final Color? tabBarUnselectedColor;
  final Color? tabBarIndicatorColor;
  
  // ============================================================================
  // Overlay Properties
  // ============================================================================
  
  final Color? overlayHeaderColor;
  final Color? overlayIconColor;
  
  // ============================================================================
  // General UI Properties
  // ============================================================================
  
  final Color? surfaceColor;
  final Color? onSurfaceColor;
  final Color? dividerColor;

  // ============================================================================
  // Light Theme Instance
  // ============================================================================
  
  static const light = HubThemeExtension(
    // Incoming (AI) Bubble - Light Mode
    incomingBubbleDecoration: BoxDecoration(
      color: Color(0xFFEEEEEE), // Colors.grey.shade200
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(kDefaultBorderRadius),
        topRight: Radius.circular(kDefaultBorderRadius),
        bottomLeft: Radius.circular(kChatBubbleSmallRadius),
        bottomRight: Radius.circular(kDefaultBorderRadius),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x1A000000), // Colors.black.withValues(alpha: 0.1)
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    // Outgoing (User) Bubble - Light Mode
    outgoingBubbleDecoration: BoxDecoration(
      color: Color(0xFF2196F3), // Colors.blue.shade500
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(kDefaultBorderRadius),
        topRight: Radius.circular(kDefaultBorderRadius),
        bottomLeft: Radius.circular(kDefaultBorderRadius),
        bottomRight: Radius.circular(kChatBubbleSmallRadius),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    // Incoming Bubble Editing State
    incomingBubbleEditingDecoration: BoxDecoration(
      color: Color(0xFFE0E0E0), // Colors.grey.shade300
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(kDefaultBorderRadius),
        topRight: Radius.circular(kDefaultBorderRadius),
        bottomLeft: Radius.circular(kChatBubbleSmallRadius),
        bottomRight: Radius.circular(kDefaultBorderRadius),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    // Outgoing Bubble Editing State
    outgoingBubbleEditingDecoration: BoxDecoration(
      color: Color(0xFF1976D2), // Colors.blue.shade700
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(kDefaultBorderRadius),
        topRight: Radius.circular(kDefaultBorderRadius),
        bottomLeft: Radius.circular(kDefaultBorderRadius),
        bottomRight: Radius.circular(kChatBubbleSmallRadius),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    // Text Styles
    incomingBubbleTextStyle: TextStyle(
      color: Color(0xDD000000), // Colors.black87
      fontSize: kDefaultTextFontSize,
    ),
    outgoingBubbleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: kDefaultTextFontSize,
    ),
    
    // Avatar Colors
    incomingBubbleAvatarColor: Color(0xFFBBDEFB), // Colors.blue.shade100
    outgoingBubbleAvatarColor: Color(0xFFC8E6C9), // Colors.green.shade100
    incomingBubbleIconColor: Color(0xFF1976D2), // Colors.blue.shade700
    outgoingBubbleIconColor: Color(0xFF388E3C), // Colors.green.shade700
    
    // Edit Icon Colors
    editCancelIconColor: Color(0xFFEF9A9A), // Colors.red.shade200
    editSaveIconColor: Color(0xFFA5D6A7), // Colors.green.shade200
    
    // Message Status Colors
    messageSendingColor: Color(0x99000000), // Light mode: grey for sending
    messageErrorColor: Color(0xFFE53935), // Colors.red.shade600
    
    // Input Bar
    inputBarDecoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: kDefaultBlurRadius,
          offset: kTopShadowOffset,
        ),
      ],
    ),
    
    inputFieldDecoration: BoxDecoration(
      color: Color(0xFFF5F5F5), // Colors.grey.shade100
      borderRadius: BorderRadius.all(Radius.circular(kInputBorderRadius)),
    ),
    
    sendButtonColor: Color(0xFF1E88E5), // Colors.blue.shade600
    sendButtonIconColor: Colors.white,
    
    // Cards and Panels
    cardDecoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(kDefaultBorderRadius)),
      boxShadow: [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    panelDecoration: BoxDecoration(
      color: Color(0xFFFAFAFA), // Colors.grey.shade50
      borderRadius: BorderRadius.all(Radius.circular(kDefaultBorderRadius)),
    ),
    
    // Action Buttons
    primaryActionButtonColor: Color(0xFF1E88E5), // Colors.blue.shade600
    secondaryActionButtonColor: Color(0xFFFFA726), // Colors.orange.shade400
    successActionButtonColor: Color(0xFF66BB6A), // Colors.green.shade400
    warningActionButtonColor: Color(0xFFFFCA28), // Colors.amber.shade400
    actionButtonTextColor: Colors.white,
    
    // Tab Bar
    tabBarSelectedColor: Color(0xFF1E88E5), // Colors.blue.shade600
    tabBarUnselectedColor: Color(0xFF9E9E9E), // Colors.grey.shade500
    tabBarIndicatorColor: Color(0xFF1E88E5), // Colors.blue.shade600
    
    // Overlay
    overlayHeaderColor: Color(0xFF616161), // Colors.grey.shade700
    overlayIconColor: Colors.white,
    
    // General UI
    surfaceColor: Colors.white,
    onSurfaceColor: Color(0xDD000000),
    dividerColor: Color(0xFFE0E0E0),
  );

  // ============================================================================
  // Dark Theme Instance
  // ============================================================================
  
  static const dark = HubThemeExtension(
    // Incoming (AI) Bubble - Dark Mode
    incomingBubbleDecoration: BoxDecoration(
      color: Color(0xFF424242), // Colors.grey.shade800
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(kDefaultBorderRadius),
        topRight: Radius.circular(kDefaultBorderRadius),
        bottomLeft: Radius.circular(kChatBubbleSmallRadius),
        bottomRight: Radius.circular(kDefaultBorderRadius),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x33000000), // Darker shadow in dark mode
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    // Outgoing (User) Bubble - Dark Mode
    outgoingBubbleDecoration: BoxDecoration(
      color: Color(0xFF1976D2), // Colors.blue.shade700
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(kDefaultBorderRadius),
        topRight: Radius.circular(kDefaultBorderRadius),
        bottomLeft: Radius.circular(kDefaultBorderRadius),
        bottomRight: Radius.circular(kChatBubbleSmallRadius),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    // Incoming Bubble Editing State - Dark Mode
    incomingBubbleEditingDecoration: BoxDecoration(
      color: Color(0xFF616161), // Colors.grey.shade700
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(kDefaultBorderRadius),
        topRight: Radius.circular(kDefaultBorderRadius),
        bottomLeft: Radius.circular(kChatBubbleSmallRadius),
        bottomRight: Radius.circular(kDefaultBorderRadius),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    // Outgoing Bubble Editing State - Dark Mode
    outgoingBubbleEditingDecoration: BoxDecoration(
      color: Color(0xFF0D47A1), // Colors.blue.shade900
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(kDefaultBorderRadius),
        topRight: Radius.circular(kDefaultBorderRadius),
        bottomLeft: Radius.circular(kDefaultBorderRadius),
        bottomRight: Radius.circular(kChatBubbleSmallRadius),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    // Text Styles - Dark Mode
    incomingBubbleTextStyle: TextStyle(
      color: Color(0xFFE0E0E0), // Light grey text for dark backgrounds
      fontSize: kDefaultTextFontSize,
    ),
    outgoingBubbleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: kDefaultTextFontSize,
    ),
    
    // Avatar Colors - Dark Mode
    incomingBubbleAvatarColor: Color(0xFF1565C0), // Darker blue
    outgoingBubbleAvatarColor: Color(0xFF2E7D32), // Darker green
    incomingBubbleIconColor: Color(0xFF90CAF9), // Lighter blue icon
    outgoingBubbleIconColor: Color(0xFF81C784), // Lighter green icon
    
    // Edit Icon Colors - Dark Mode
    editCancelIconColor: Color(0xFFE57373), // Lighter red for visibility
    editSaveIconColor: Color(0xFF81C784), // Lighter green for visibility
    
    // Message Status Colors - Dark Mode
    messageSendingColor: Color(0xB3FFFFFF), // White with alpha for sending
    messageErrorColor: Color(0xFFEF5350), // Lighter red for dark mode
    
    // Input Bar - Dark Mode
    inputBarDecoration: BoxDecoration(
      color: Color(0xFF212121), // Dark surface
      boxShadow: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: kDefaultBlurRadius,
          offset: kTopShadowOffset,
        ),
      ],
    ),
    
    inputFieldDecoration: BoxDecoration(
      color: Color(0xFF424242), // Darker input field
      borderRadius: BorderRadius.all(Radius.circular(kInputBorderRadius)),
    ),
    
    sendButtonColor: Color(0xFF1976D2), // Blue.shade700
    sendButtonIconColor: Colors.white,
    
    // Cards and Panels - Dark Mode
    cardDecoration: BoxDecoration(
      color: Color(0xFF424242),
      borderRadius: BorderRadius.all(Radius.circular(kDefaultBorderRadius)),
      boxShadow: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: kSmallBlurRadius,
          offset: kDefaultShadowOffset,
        ),
      ],
    ),
    
    panelDecoration: BoxDecoration(
      color: Color(0xFF303030),
      borderRadius: BorderRadius.all(Radius.circular(kDefaultBorderRadius)),
    ),
    
    // Action Buttons - Dark Mode
    primaryActionButtonColor: Color(0xFF1976D2), // Colors.blue.shade700
    secondaryActionButtonColor: Color(0xFFFB8C00), // Colors.orange.shade700
    successActionButtonColor: Color(0xFF43A047), // Colors.green.shade600
    warningActionButtonColor: Color(0xFFFFB300), // Colors.amber.shade600
    actionButtonTextColor: Colors.white,
    
    // Tab Bar - Dark Mode
    tabBarSelectedColor: Color(0xFF42A5F5), // Colors.blue.shade400 (lighter for dark mode)
    tabBarUnselectedColor: Color(0xFF757575), // Colors.grey.shade600
    tabBarIndicatorColor: Color(0xFF42A5F5), // Colors.blue.shade400
    
    // Overlay - Dark Mode
    overlayHeaderColor: Color(0xFF424242), // Colors.grey.shade800
    overlayIconColor: Color(0xFFE0E0E0), // Lighter for dark mode
    
    // General UI - Dark Mode
    surfaceColor: Color(0xFF212121),
    onSurfaceColor: Color(0xFFE0E0E0),
    dividerColor: Color(0xFF424242),
  );

  // ============================================================================
  // ThemeExtension Contract Implementation
  // ============================================================================
  
  @override
  HubThemeExtension copyWith({
    BoxDecoration? incomingBubbleDecoration,
    BoxDecoration? outgoingBubbleDecoration,
    BoxDecoration? incomingBubbleEditingDecoration,
    BoxDecoration? outgoingBubbleEditingDecoration,
    TextStyle? incomingBubbleTextStyle,
    TextStyle? outgoingBubbleTextStyle,
    Color? incomingBubbleAvatarColor,
    Color? outgoingBubbleAvatarColor,
    Color? incomingBubbleIconColor,
    Color? outgoingBubbleIconColor,
    Color? editCancelIconColor,
    Color? editSaveIconColor,
    Color? messageSendingColor,
    Color? messageErrorColor,
    BoxDecoration? inputBarDecoration,
    BoxDecoration? inputFieldDecoration,
    Color? sendButtonColor,
    Color? sendButtonIconColor,
    BoxDecoration? cardDecoration,
    BoxDecoration? panelDecoration,
    Color? primaryActionButtonColor,
    Color? secondaryActionButtonColor,
    Color? successActionButtonColor,
    Color? warningActionButtonColor,
    Color? actionButtonTextColor,
    Color? tabBarSelectedColor,
    Color? tabBarUnselectedColor,
    Color? tabBarIndicatorColor,
    Color? overlayHeaderColor,
    Color? overlayIconColor,
    Color? surfaceColor,
    Color? onSurfaceColor,
    Color? dividerColor,
  }) {
    return HubThemeExtension(
      incomingBubbleDecoration: incomingBubbleDecoration ?? this.incomingBubbleDecoration,
      outgoingBubbleDecoration: outgoingBubbleDecoration ?? this.outgoingBubbleDecoration,
      incomingBubbleEditingDecoration: incomingBubbleEditingDecoration ?? this.incomingBubbleEditingDecoration,
      outgoingBubbleEditingDecoration: outgoingBubbleEditingDecoration ?? this.outgoingBubbleEditingDecoration,
      incomingBubbleTextStyle: incomingBubbleTextStyle ?? this.incomingBubbleTextStyle,
      outgoingBubbleTextStyle: outgoingBubbleTextStyle ?? this.outgoingBubbleTextStyle,
      incomingBubbleAvatarColor: incomingBubbleAvatarColor ?? this.incomingBubbleAvatarColor,
      outgoingBubbleAvatarColor: outgoingBubbleAvatarColor ?? this.outgoingBubbleAvatarColor,
      incomingBubbleIconColor: incomingBubbleIconColor ?? this.incomingBubbleIconColor,
      outgoingBubbleIconColor: outgoingBubbleIconColor ?? this.outgoingBubbleIconColor,
      editCancelIconColor: editCancelIconColor ?? this.editCancelIconColor,
      editSaveIconColor: editSaveIconColor ?? this.editSaveIconColor,
      messageSendingColor: messageSendingColor ?? this.messageSendingColor,
      messageErrorColor: messageErrorColor ?? this.messageErrorColor,
      inputBarDecoration: inputBarDecoration ?? this.inputBarDecoration,
      inputFieldDecoration: inputFieldDecoration ?? this.inputFieldDecoration,
      sendButtonColor: sendButtonColor ?? this.sendButtonColor,
      sendButtonIconColor: sendButtonIconColor ?? this.sendButtonIconColor,
      cardDecoration: cardDecoration ?? this.cardDecoration,
      panelDecoration: panelDecoration ?? this.panelDecoration,
      primaryActionButtonColor: primaryActionButtonColor ?? this.primaryActionButtonColor,
      secondaryActionButtonColor: secondaryActionButtonColor ?? this.secondaryActionButtonColor,
      successActionButtonColor: successActionButtonColor ?? this.successActionButtonColor,
      warningActionButtonColor: warningActionButtonColor ?? this.warningActionButtonColor,
      actionButtonTextColor: actionButtonTextColor ?? this.actionButtonTextColor,
      tabBarSelectedColor: tabBarSelectedColor ?? this.tabBarSelectedColor,
      tabBarUnselectedColor: tabBarUnselectedColor ?? this.tabBarUnselectedColor,
      tabBarIndicatorColor: tabBarIndicatorColor ?? this.tabBarIndicatorColor,
      overlayHeaderColor: overlayHeaderColor ?? this.overlayHeaderColor,
      overlayIconColor: overlayIconColor ?? this.overlayIconColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      onSurfaceColor: onSurfaceColor ?? this.onSurfaceColor,
      dividerColor: dividerColor ?? this.dividerColor,
    );
  }

  /// WHY: The lerp method is critical for animated theme transitions.
  /// It must delegate to the native lerp methods of each style object type
  /// to ensure smooth, performant animations when switching between themes.
  @override
  HubThemeExtension lerp(ThemeExtension<HubThemeExtension>? other, double t) {
    if (other is! HubThemeExtension) {
      return this;
    }
    
    return HubThemeExtension(
      incomingBubbleDecoration: BoxDecoration.lerp(
        incomingBubbleDecoration,
        other.incomingBubbleDecoration,
        t,
      ),
      outgoingBubbleDecoration: BoxDecoration.lerp(
        outgoingBubbleDecoration,
        other.outgoingBubbleDecoration,
        t,
      ),
      incomingBubbleEditingDecoration: BoxDecoration.lerp(
        incomingBubbleEditingDecoration,
        other.incomingBubbleEditingDecoration,
        t,
      ),
      outgoingBubbleEditingDecoration: BoxDecoration.lerp(
        outgoingBubbleEditingDecoration,
        other.outgoingBubbleEditingDecoration,
        t,
      ),
      incomingBubbleTextStyle: TextStyle.lerp(
        incomingBubbleTextStyle,
        other.incomingBubbleTextStyle,
        t,
      ),
      outgoingBubbleTextStyle: TextStyle.lerp(
        outgoingBubbleTextStyle,
        other.outgoingBubbleTextStyle,
        t,
      ),
      incomingBubbleAvatarColor: Color.lerp(
        incomingBubbleAvatarColor,
        other.incomingBubbleAvatarColor,
        t,
      ),
      outgoingBubbleAvatarColor: Color.lerp(
        outgoingBubbleAvatarColor,
        other.outgoingBubbleAvatarColor,
        t,
      ),
      incomingBubbleIconColor: Color.lerp(
        incomingBubbleIconColor,
        other.incomingBubbleIconColor,
        t,
      ),
      outgoingBubbleIconColor: Color.lerp(
        outgoingBubbleIconColor,
        other.outgoingBubbleIconColor,
        t,
      ),
      editCancelIconColor: Color.lerp(
        editCancelIconColor,
        other.editCancelIconColor,
        t,
      ),
      editSaveIconColor: Color.lerp(
        editSaveIconColor,
        other.editSaveIconColor,
        t,
      ),
      messageSendingColor: Color.lerp(
        messageSendingColor,
        other.messageSendingColor,
        t,
      ),
      messageErrorColor: Color.lerp(
        messageErrorColor,
        other.messageErrorColor,
        t,
      ),
      inputBarDecoration: BoxDecoration.lerp(
        inputBarDecoration,
        other.inputBarDecoration,
        t,
      ),
      inputFieldDecoration: BoxDecoration.lerp(
        inputFieldDecoration,
        other.inputFieldDecoration,
        t,
      ),
      sendButtonColor: Color.lerp(
        sendButtonColor,
        other.sendButtonColor,
        t,
      ),
      sendButtonIconColor: Color.lerp(
        sendButtonIconColor,
        other.sendButtonIconColor,
        t,
      ),
      cardDecoration: BoxDecoration.lerp(
        cardDecoration,
        other.cardDecoration,
        t,
      ),
      panelDecoration: BoxDecoration.lerp(
        panelDecoration,
        other.panelDecoration,
        t,
      ),
      primaryActionButtonColor: Color.lerp(
        primaryActionButtonColor,
        other.primaryActionButtonColor,
        t,
      ),
      secondaryActionButtonColor: Color.lerp(
        secondaryActionButtonColor,
        other.secondaryActionButtonColor,
        t,
      ),
      successActionButtonColor: Color.lerp(
        successActionButtonColor,
        other.successActionButtonColor,
        t,
      ),
      warningActionButtonColor: Color.lerp(
        warningActionButtonColor,
        other.warningActionButtonColor,
        t,
      ),
      actionButtonTextColor: Color.lerp(
        actionButtonTextColor,
        other.actionButtonTextColor,
        t,
      ),
      tabBarSelectedColor: Color.lerp(
        tabBarSelectedColor,
        other.tabBarSelectedColor,
        t,
      ),
      tabBarUnselectedColor: Color.lerp(
        tabBarUnselectedColor,
        other.tabBarUnselectedColor,
        t,
      ),
      tabBarIndicatorColor: Color.lerp(
        tabBarIndicatorColor,
        other.tabBarIndicatorColor,
        t,
      ),
      overlayHeaderColor: Color.lerp(
        overlayHeaderColor,
        other.overlayHeaderColor,
        t,
      ),
      overlayIconColor: Color.lerp(
        overlayIconColor,
        other.overlayIconColor,
        t,
      ),
      surfaceColor: Color.lerp(
        surfaceColor,
        other.surfaceColor,
        t,
      ),
      onSurfaceColor: Color.lerp(
        onSurfaceColor,
        other.onSurfaceColor,
        t,
      ),
      dividerColor: Color.lerp(
        dividerColor,
        other.dividerColor,
        t,
      ),
    );
  }
}
