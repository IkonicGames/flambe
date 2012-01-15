//
// Flambe - Rapid game development
// https://github.com/aduros/flambe/blob/master/LICENSE.txt

package flambe.asset;

import haxe.rtti.Meta;

import flambe.asset.AssetEntry;
import flambe.macro.ManifestBuilder;

using flambe.util.Strings;

class Manifest
{
    public function new ()
    {
        _entries = [];
    }

    // Get a manifest of a pack in the asset directory at build-time
    public static function build (packName :String) :Manifest
    {
        return _buildManifest.get(packName);
    }

    /**
     * Try to find a pack suffixed with the closest available variant of the locale. For example,
     * buildLocalized("foo", "pt-BR") will first try to load foo_pt-BR, then foo_pt, then just foo.
     */
    public static function buildLocalized (packName :String, locale :String = null) :Manifest
    {
        if (locale == null) {
            locale = System.locale;
        }

        if (locale != null) {
            var parts = locale.split("-");
            while (parts.length > 0) {
                var manifest = build(packName + "_" + parts.join("-"));
                if (manifest != null) {
                    return manifest;
                }
                parts.pop();
            }
        }
        return build(packName);
    }

    public static function exists (packName :String) :Bool
    {
        return _buildManifest.exists(packName);
    }

    public function add (name :String, url :String, bytes :Int = 0, ?type :AssetType) :AssetEntry
    {
        if (type == null) {
            type = inferType(url);
        }

        var entry = new AssetEntry(name, url, type, bytes);
        _entries.push(entry);
        return entry;
    }

    public function getEntries () :Array<AssetEntry>
    {
        return _entries.copy();
    }

    private static function inferType (url :String) :AssetType
    {
        return switch (url.split("?")[0].getFileExtension().toLowerCase()) {
            case "png", "jpg", "gif": Image;
            case "ogg", "m4a", "mp3", "wav": Audio;
            default: Data;
        }
    }

    private static function createBuildManifests ()
    {
        var macroData = new Hash<Array<Dynamic>>();
        ManifestBuilder.populate(macroData);

        // The path to our asset packs
        var base = "assets";

        // Use the custom asset base provided by the build, if we support CORS
        var meta = Meta.getType(Manifest);
        if (meta.assetBase != null && supportsCrossOrigin()) {
            base = meta.assetBase[0];
        }

        // Ensure it ends with a trailing slash
        if (base.charAt(base.length - 1) != "/") {
            base += "/";
        }

        var manifests = new Hash();
        for (packName in macroData.keys()) {
            var manifest = new Manifest();
            for (asset in macroData.get(packName)) {
                var name = asset.name;
                var url = base + packName + "/" + name + "?v=" + asset.md5;
                var type = inferType(url);
                if (type == Audio) {
                    // If this an asset that not all platforms may support, trim the extension from
                    // the name. We'll only load one of the assets if this creates a name collision.
                    name = name.substr(0, name.lastIndexOf("."));
                }

                manifest.add(name, url, asset.bytes, type);
            }
            manifests.set(packName, manifest);
        }
        return manifests;
    }

    /**
     * Returns true if the environment fully supports loading assets on another domain.
     */
    private static function supportsCrossOrigin () :Bool
    {
#if js
        var xhr :Dynamic = new js.XMLHttpRequest();
        return (xhr.withCredentials != null);
#else
        return true;
#end
    }

    private static var _buildManifest :Hash<Manifest> = createBuildManifests();

    private var _entries :Array<AssetEntry>;
}
