/* translations.js
 * 
 * Internationalization support for Redragon HS Companion
 * Supports: English, Portuguese, Spanish
 */

export const translations = {
    'en': {
        // Status
        'detecting': 'Detecting...',
        'connected': 'Connected',
        'disconnected': 'Disconnected',
        'not_found': 'Not found',
        
        // Actions
        'synchronize_now': 'Synchronize Now',
        'settings': 'Settings',
        'mute': 'Mute',
        'unmute': 'Unmute',
        'use_as_output': 'Use as audio output',
        
        // Notifications
        'headset_not_connected': 'Headset not connected',
        'volume_updated': 'Volume updated!',
        'error_updating': 'Error updating volume',
        'set_as_default': '{{device}} set as default output',
        
        // Errors
        'script_not_installed': 'Script not installed',
        'error': 'Error',
    },
    
    'pt': {
        // Status
        'detecting': 'Detectando...',
        'connected': 'Conectado',
        'disconnected': 'Desconectado',
        'not_found': 'Não encontrado',
        
        // Actions
        'synchronize_now': 'Sincronizar Agora',
        'settings': 'Configurações',
        'mute': 'Mutar',
        'unmute': 'Desmutar',
        'use_as_output': 'Usar como saída de áudio',
        
        // Notifications
        'headset_not_connected': 'Headset não conectado',
        'volume_updated': 'Volume atualizado!',
        'error_updating': 'Erro ao atualizar volume',
        'set_as_default': '{{device}} definido como saída padrão',
        
        // Errors
        'script_not_installed': 'Script não instalado',
        'error': 'Erro',
    },
    
    'es': {
        // Status
        'detecting': 'Detectando...',
        'connected': 'Conectado',
        'disconnected': 'Desconectado',
        'not_found': 'No encontrado',
        
        // Actions
        'synchronize_now': 'Sincronizar Ahora',
        'settings': 'Configuraciones',
        'mute': 'Silenciar',
        'unmute': 'Activar Sonido',
        'use_as_output': 'Usar como salida de audio',
        
        // Notifications
        'headset_not_connected': 'Auriculares no conectados',
        'volume_updated': '¡Volumen actualizado!',
        'error_updating': 'Error al actualizar volumen',
        'set_as_default': '{{device}} establecido como salida predeterminada',
        
        // Errors
        'script_not_installed': 'Script no instalado',
        'error': 'Error',
    }
};

export class Translator {
    constructor() {
        this._locale = this._detectLocale();
        this._lang = this._getLanguage(this._locale);
    }
    
    _detectLocale() {
        // Try to get system locale
        const lang = GLib.getenv('LANG') || GLib.getenv('LANGUAGE') || 'en_US.UTF-8';
        return lang.split('.')[0]; // Returns 'pt_BR', 'en_US', 'es_ES', etc
    }
    
    _getLanguage(locale) {
        // Extract language code (pt, en, es)
        const langCode = locale.split('_')[0].toLowerCase();
        
        // Check if we have translations for this language
        if (translations[langCode]) {
            return langCode;
        }
        
        // Default to English
        return 'en';
    }
    
    translate(key, params = {}) {
        const lang = translations[this._lang];
        let text = lang[key] || translations['en'][key] || key;
        
        // Replace parameters (e.g., {{device}})
        for (const [paramKey, paramValue] of Object.entries(params)) {
            text = text.replace(`{{${paramKey}}}`, paramValue);
        }
        
        return text;
    }
    
    // Shorthand method
    _(key, params = {}) {
        return this.translate(key, params);
    }
}

