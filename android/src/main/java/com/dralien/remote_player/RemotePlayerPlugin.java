package com.dralien.remote_player;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.media.MediaBrowserCompat;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;

import com.dralien.remote_player.client.MediaBrowserHelper;
import com.dralien.remote_player.service.MusicService;
import com.dralien.remote_player.service.contentcatalogs.MusicLibrary;

import java.util.HashMap;
import java.util.List;
import java.util.concurrent.TimeUnit;

import androidx.annotation.NonNull;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.PluginRegistry.Registrar;

enum RemotePlayerState {
  stopped,
  paused,
  playing,
  resuming,
  error
}

/** RemotePlayerPlugin */
public class RemotePlayerPlugin implements MethodCallHandler, EventChannel.StreamHandler {
  public Registrar registrar;

  MethodChannel channel;
  EventChannel eventChannel;
  EventChannel.EventSink eventSink;

  MediaBrowserConnection mediaBrowserHelper;
  Handler handler;
  Runnable runnable;

  public static RemotePlayerPlugin shared;

  /** Plugin registration. */
  public static void registerWith(Registrar registrar) {
    RemotePlayerPlugin.shared = new RemotePlayerPlugin(registrar);
  }

  RemotePlayerPlugin(Registrar registrar) {
    this.registrar = registrar;

    this.channel = new MethodChannel(registrar.messenger(), "com.dralien/remote_player");
    this.eventChannel = new EventChannel(registrar.messenger(), "com.dralien/remote_player/event");

    channel.setMethodCallHandler(this);
    eventChannel.setStreamHandler(this);

    mediaBrowserHelper = new MediaBrowserConnection(registrar.activity());
    mediaBrowserHelper.registerCallback(new MediaBrowserListener());

    handler = new Handler();
    runnable = new Runnable() {
      @Override
      public void run() {
        try {
          Log.i("time", String.valueOf(mediaBrowserHelper.getController().getPlaybackState().getPosition()));
          if (onDurationChanged((int)mediaBrowserHelper.getController().getPlaybackState().getPosition())) {
            handler.postDelayed(this, 10);
          }
        } catch (Exception ex) {
          Log.e("error", ex.getMessage());
        }
      }
    };
  }

  public boolean onDurationChanged(int duration) {
    try {
      double _duration = duration / 1000.0;

      HashMap<String, Object> eventValue = new HashMap<>();
      eventValue.put("event", "onDuration");
      eventValue.put("duration", _duration);

      this.eventSink.success(eventValue);
      return true;
    } catch (Exception ex) {
      //ex.printStackTrace();
    }
    return false;
  }

  public boolean onStateChanged(int state) {
    try {
      Log.i("state", String.valueOf(state));

      HashMap<String, Object> eventValue = new HashMap<>();
      eventValue.put("event", "onState");
      eventValue.put("state", state);

      this.eventSink.success(eventValue);
      return true;
    } catch (Exception ex) {
      //ex.printStackTrace();
    }
    return false;
  }

  @Override
  public void onListen(Object o, EventChannel.EventSink eventSink) {
    this.eventSink = eventSink;
  }

  @Override
  public void onCancel(Object o) {
    this.eventSink = null;
  }

  void handlePlay(MethodCall call, MethodChannel.Result result) {
    handler.removeCallbacks(runnable);
    try {
      mediaBrowserHelper.getTransportControls().stop();
    } catch (Exception ex) { }
    mediaBrowserHelper.onStop();
    mediaBrowserHelper.onStartWithListener(new ServiceListener() {
      @Override
      public void onChildrenLoaded() {
        mediaBrowserHelper.getTransportControls().play();
        handler.post(runnable);
      }
    });
  }

  void handleSetup() {
    handler.removeCallbacks(runnable);
    try {
      mediaBrowserHelper.getTransportControls().stop();
    } catch (Exception ex) { }
    mediaBrowserHelper.onStop();
    mediaBrowserHelper.onStartWithListener(new ServiceListener() {
      @Override
      public void onChildrenLoaded() {
        int state = mediaBrowserHelper.getController().getPlaybackState().getState();
        if (state == PlaybackStateCompat.STATE_PLAYING) {
          handler.post(runnable);
        } else if (state == PlaybackStateCompat.STATE_PAUSED) {
          onDurationChanged((int)mediaBrowserHelper.getController().getPlaybackState().getPosition());
        }
      }
    });
  }

  int getResourceId(String resource) {
    String[] parts = resource.split("/");
    String resourceType = parts[0];
    String resourceName = parts[1];
    Context context = RemotePlayerPlugin.shared.registrar.context();
    return context.getResources().getIdentifier(resourceName, resourceType, context.getPackageName());
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    Intent i = new Intent(registrar.context(), MusicService.class);
    if (call.method.equals("setup")) {
      try {
        Bundle extras = this.registrar.activity().getIntent().getExtras();
        if (extras.getString("from").equals("notification")) {
          handleSetup();
        }
      } catch (Exception ex) {
        Log.e("a", ex.getMessage());
      }
      result.success("setup");
    } else if (call.method.equals("play")) {
      result.success("play");

      int iconId = getResourceId("mipmap/ic_launcher");

      MusicLibrary.music.clear();
      MusicLibrary.createMediaMetadataCompat(
              "com.dralien.remote_player/music",
              call.argument("title").toString(),
              call.argument("artist").toString(),
              call.argument("album").toString(),
              "Итгэл",
              103,
              TimeUnit.SECONDS,
              call.argument("url").toString(),
              iconId,
              "mipmap/ic_launcher");

      onStateChanged(RemotePlayerState.stopped.ordinal());
      handlePlay(call, result);
    } else if (call.method.equals("pause")) {
      mediaBrowserHelper.getTransportControls().pause();
      handler.removeCallbacks(runnable);
      result.success("pause");
    } else if (call.method.equals("resume")) {
      handler.removeCallbacks(runnable);
      handler.post(runnable);
      mediaBrowserHelper.getTransportControls().play();
      result.success("resume");
    } else if (call.method.equals("stop")) {
      result.success("stop");
      handler.removeCallbacks(runnable);
      mediaBrowserHelper.getTransportControls().stop();
      mediaBrowserHelper.onStop();
      onDurationChanged(0);
      onStateChanged(RemotePlayerState.stopped.ordinal());
    } else if (call.method.equals("toggle")) {
      result.success("toggle");
    } else {
      result.notImplemented();
    }
  }

  private class MediaBrowserConnection extends MediaBrowserHelper {
    private ServiceListener serviceListener;
    MediaControllerCompat _mediaController;

    private MediaBrowserConnection(Context context) {
      super(context, MusicService.class);
    }

    public void onStartWithListener(ServiceListener listener) {
      this.serviceListener = listener;
      super.onStart();
    }

    @Override
    protected void onConnected(@NonNull MediaControllerCompat mediaController) {
      //mSeekBarAudio.setMediaController(mediaController);
      Log.i("connection", "connected");
    }

    @Override
    protected void onChildrenLoaded(@NonNull String parentId,
                                    @NonNull List<MediaBrowserCompat.MediaItem> children) {
      super.onChildrenLoaded(parentId, children);

      final MediaControllerCompat mediaController = getMediaController();
      _mediaController = getMediaController();

      // Queue up all media items for this simple sample.
      for (final MediaBrowserCompat.MediaItem mediaItem : children) {
        mediaController.addQueueItem(mediaItem.getDescription());
      }

      // Call prepare now so pressing play just works.
      mediaController.getTransportControls().prepare();

      Log.i("children", "loaded");

      if (serviceListener != null) {
        serviceListener.onChildrenLoaded();
      }
    }

    public MediaControllerCompat getController() {
      return _mediaController;
    }
  }

  /**
   * Implementation of the {@link MediaControllerCompat.Callback} methods we're interested in.
   * <p>
   * Here would also be where one could override
   * {@code onQueueChanged(List<MediaSessionCompat.QueueItem> queue)} to get informed when items
   * are added or removed from the queue. We don't do this here in order to keep the UI
   * simple.
   */
  private class MediaBrowserListener extends MediaControllerCompat.Callback {
    @Override
    public void onPlaybackStateChanged(PlaybackStateCompat playbackState) {
      try {
        if (playbackState != null) {
          Log.i("state", playbackState.toString());

          RemotePlayerState _state = null;
          switch (playbackState.getState()) {
            case PlaybackStateCompat.STATE_PLAYING: _state = RemotePlayerState.playing; break;
            case PlaybackStateCompat.STATE_STOPPED: _state = RemotePlayerState.stopped; break;
            case PlaybackStateCompat.STATE_PAUSED: _state = RemotePlayerState.paused; break;
            case PlaybackStateCompat.STATE_ERROR: _state = RemotePlayerState.error; break;
            case PlaybackStateCompat.STATE_CONNECTING: _state = RemotePlayerState.resuming; break;
          }

          if (_state == RemotePlayerState.paused || _state == RemotePlayerState.stopped) {
            handler.removeCallbacks(runnable);
          } else if (_state == RemotePlayerState.playing) {
            handler.post(runnable);
          }

          onStateChanged(_state.ordinal());
        }
      } catch (Exception ex) {
        Log.e("onStateChanged", ex.getMessage());
      }
    }

    @Override
    public void onMetadataChanged(MediaMetadataCompat mediaMetadata) {
      if (mediaMetadata == null) {
        return;
      }
    }

    @Override
    public void onSessionDestroyed() {
      super.onSessionDestroyed();
    }

    @Override
    public void onQueueChanged(List<MediaSessionCompat.QueueItem> queue) {
      super.onQueueChanged(queue);
    }
  }

  private interface ServiceListener {
    void onChildrenLoaded();
  }
}