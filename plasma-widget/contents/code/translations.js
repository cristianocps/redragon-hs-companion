/* translations.js
 * 
 * Internationalization support for Redragon HS Companion - KDE Plasma
 * Supports: English, Portuguese, Spanish
 */

.pragma library

var translations = {
    'en': {
        // Status
        'not_found': 'Not found',
        'connected': 'Connected',
        'mute': 'Mute',
        'unmute': 'Unmute',
        'use_as_output': 'Use as audio output',
        'set_as_default': '%1 set as default output'
    },
    
    'pt': {
        // Status
        'not_found': 'Não encontrado',
        'connected': 'Conectado',
        'mute': 'Mutar',
        'unmute': 'Desmutar',
        'use_as_output': 'Usar como saída de áudio',
        'set_as_default': '%1 definido como saída padrão'
    },
    
    'es': {
        // Status
        'not_found': 'No encontrado',
        'connected': 'Conectado',
        'mute': 'Silenciar',
        'unmute': 'Activar Sonido',
        'use_as_output': 'Usar como salida de audio',
        'set_as_default': '%1 establecido como salida predeterminada'
    }
};

function detectLocale() {
    // Try to get system locale
    var lang = Qt.locale().name; // Returns 'pt_BR', 'en_US', 'es_ES', etc
    return lang;
}

function getLanguage(locale) {
    // Extract language code (pt, en, es)
    var langCode = locale.split('_')[0].toLowerCase();
    
    // Check if we have translations for this language
    if (translations[langCode]) {
        return langCode;
    }
    
    // Default to English
    return 'en';
}

function translate(key, args) {
    var locale = detectLocale();
    var lang = getLanguage(locale);
    
    var text = translations[lang][key] || translations['en'][key] || key;
    
    // Replace %1, %2, etc with arguments
    if (args) {
        for (var i = 0; i < args.length; i++) {
            text = text.replace('%' + (i + 1), args[i]);
        }
    }
    
    return text;
}

function _(key, args) {
    return translate(key, args);
}

