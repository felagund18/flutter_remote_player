#import "RemotePlayerPlugin.h"
#import <remote_player/remote_player-Swift.h>
//#import "remote_player-Swift.h"

@implementation RemotePlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftRemotePlayerPlugin registerWithRegistrar:registrar];
}
@end
