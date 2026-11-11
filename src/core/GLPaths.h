// Application storage. Library track paths are relative to Media; uploads and
// imported files continue to use Media/Groovelet.

#import <Foundation/Foundation.h>

// Media/Groovelet in the home directory. The music is here.
// The app is in /Applications, so its home directory is /var/mobile, which
// all such apps share. /var/mobile/Media is the root of AFC, so a computer
// copies files into this directory over USB with no jailbreak tool.
NSString *GLMusicDirectory(void);
// The root of selectable music folders. Track paths are relative to this.
NSString *GLMediaDirectory(void);
// Library/Application Support/Groovelet. The index and the state are here.
NSString *GLSupportDirectory(void);
// Library/Caches/Groovelet. The art thumbnails are here.
NSString *GLCacheDirectory(void);

// The full path of a path that is relative to Media.
NSString *GLAbsolutePath(NSString *relativePath);
// The path relative to Media, or nil for a path outside it.
NSString *GLRelativePath(NSString *absolutePath);

// Changes the root of all paths, for the tests.
void GLSetRootDirectory(NSString *directory);
