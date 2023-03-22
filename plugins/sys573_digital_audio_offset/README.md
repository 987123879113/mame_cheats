# sys573_digital_audio_offset MAME plugin

The plugin is provided as-is and is an unofficial hack so please do not report issues to upstream mamedev that are the result of this plugin. This plugin works by hooking the audio timer register read by all System 573 digital hardware games and may not work perfectly in every game depending on how it uses the timer register.

## Configuration

Here is an example settings.json commented to explain how to add game-specific offsets and a global offset to be used for all games that use the System 573 digital hardware.

A default offset of 28ms is what I personally found to be more useful when using Windows + Portaudio + WASAPI for lowest audio latency. I suggest you play around with the global offset to figure out what works best for your setup.

```json
{
    "default": "28ms", // Specify a default value to offset all Sys573 digital audio by unless an override is specified
                       // Setting this to 0 is the equivalent of disabling the default override.
                       // Can be either a samples-based (1234) or millisecond-based (1234ms) value.
    "overrides": {
        "ddrmax": 1234, // Sample-based override offset for the game "ddrmax"
        "ddr5m": "50ms", // Millisecond-based override offset, gets converted to samples automatically for the game "ddr5m"
    }
}
```