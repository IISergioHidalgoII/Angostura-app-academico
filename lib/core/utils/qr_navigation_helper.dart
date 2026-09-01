/// Helper para compartir el ID de la carta escaneada entre QR Scanner y Collection
class QRNavigationHelper {
  static String? pendingHighlightCardId;

  static void setHighlightCard(String cardId) {
    pendingHighlightCardId = cardId;
  }

  static String? consumeHighlightCard() {
    final cardId = pendingHighlightCardId;
    pendingHighlightCardId = null;
    return cardId;
  }

  static void clear() {
    pendingHighlightCardId = null;
  }
}
