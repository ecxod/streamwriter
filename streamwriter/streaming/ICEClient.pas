{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2011 Alexander Nottelmann

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 3
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
    ------------------------------------------------------------------------
}
unit ICEClient;

interface

uses
  SysUtils, Windows, StrUtils, Classes, ICEThread, ICEStream, AppData,
  Generics.Collections, Functions, Sockets, Plugins, LanguageObjects,
  DataManager, HomeCommunication, PlayerManager, Notifications,
  Logging;

type
  // Vorsicht: Das hier bestimmt die Sortierreihenfolge im MainForm.
  TICEClientStates = (csConnecting, csConnected, csStopping, csStopped, csRetrying, csIOError);

  TDebugTypes = (dtSocket, dtMessage, dtSong, dtError);
  TDebugLevels = (dlNormal, dlDebug);

  TICEClient = class;

  TDebugEntry = class
  public
    Text: string;
    Data: string;
    T: TDebugTypes;
    Level: TDebugLevels;
    Time: TDateTime;
    constructor Create(Text, Data: string; T: TDebugTypes; Level: TDebugLevels);
  end;

  TURLList = class(TStringList)
  public
    function Add(const S: string): Integer; override;
  end;

  TDebugLog = class(TObjectList<TDebugEntry>)
  protected
    procedure Notify(const Item: TDebugEntry; Action: TCollectionNotification); override;
  end;

  TIntegerEvent = procedure(Sender: TObject; Data: Integer) of object;
  TStringEvent = procedure(Sender: TObject; Data: string) of object;
  TSongSavedEvent = procedure(Sender: TObject; Filename, Title: string; Filesize, Length: UInt64; WasCut, FullTitle: Boolean) of object;
  TTitleAllowedEvent = procedure(Sender: TObject; Title: string; var Allowed: Boolean; var Match: string; var Filter: Integer) of object;

  TICEClient = class
  private
    FEntry: TStreamEntry;

    FDebugLog: TDebugLog;
    FICEThread: TICEThread;
    FProcessingList: TProcessingList;

    FURLsIndex: Integer;
    FCurrentURL: string;
    FState: TICEClientStates;
    FRedirectedURL: string;
    FGenre: string;
    FTitle: string;
    FSpeed: Integer;
    FContentType: string;
    FFilename: string;

    FAutoRemove: Boolean;
    FRecordTitle: string;
    FStopAfterSong: Boolean;
    FKilled: Boolean;
    FRetries: Integer;

    FOnDebug: TNotifyEvent;
    FOnRefresh: TNotifyEvent;
    FOnSongSaved: TSongSavedEvent;
    FOnTitleChanged: TStringEvent;
    FOnDisconnected: TNotifyEvent;
    FOnAddRecent: TNotifyEvent;
    FOnICYReceived: TIntegerEvent;
    FOnURLsReceived: TNotifyEvent;
    FOnTitleAllowed: TTitleAllowedEvent;

    FOnPlay: TNotifyEvent;
    FOnPause: TNotifyEvent;
    FOnStop: TNotifyEvent;

    procedure Connect;
    procedure Disconnect;

    procedure Initialize;
    procedure Start;
    function FGetActive: Boolean;
    function FGetRecording: Boolean;
    function FGetPaused: Boolean;
    function FGetPlaying: Boolean;
    function ParsePlaylist: Boolean;
    function GetURL: string;

    procedure ThreadDebug(Sender: TSocketThread);
    procedure ThreadAddRecent(Sender: TSocketThread);
    procedure ThreadSpeedChanged(Sender: TSocketThread);
    procedure ThreadTitleChanged(Sender: TSocketThread);
    procedure ThreadSongSaved(Sender: TSocketThread);
    procedure ThreadStateChanged(Sender: TSocketThread);
    procedure ThreadNeedSettings(Sender: TSocketThread);
    procedure ThreadTitleAllowed(Sender: TSocketThread);
    procedure ThreadBeforeEnded(Sender: TSocketThread);
    procedure ThreadTerminated(Sender: TObject);

    procedure PluginThreadTerminate(Sender: TObject);
  public
    constructor Create(StartURL: string); overload;
    constructor Create(Name, StartURL: string); overload;
    constructor Create(Entry: TStreamEntry); overload;
    destructor Destroy; override;

    procedure WriteDebug(Text, Data: string; T: TDebugTypes; Level: TDebugLevels); overload;
    procedure WriteDebug(Text: string; T: TDebugTypes; Level: TDebugLevels); overload;

    procedure StartPlay;
    procedure PausePlay;
    procedure StopPlay;
    procedure StartRecording;
    procedure StopRecording;
    procedure SetVolume(Vol: Integer);

    procedure Kill;
    procedure SetSettings(Settings: TStreamSettings);

    property AutoRemove: Boolean read FAutoRemove write FAutoRemove;
    property RecordTitle: string read FRecordTitle write FRecordTitle;
    property StopAfterSong: Boolean read FStopAfterSong write FStopAfterSong;

    property Entry: TStreamEntry read FEntry;

    property DebugLog: TDebugLog read FDebugLog;
    property Active: Boolean read FGetActive;
    property Recording: Boolean read FGetRecording;
    property Playing: Boolean read FGetPlaying;
    property Paused: Boolean read FGetPaused;
    property Killed: Boolean read FKilled;
    property State: TICEClientStates read FState;
    property Genre: string read FGenre;
    property Title: string read FTitle;
    property Speed: Integer read FSpeed;
    property ContentType: string read FContentType;
    property Filename: string read FFilename;

    property ProcessingList: TProcessingList read FProcessingList;

    property OnDebug: TNotifyEvent read FOnDebug write FOnDebug;
    property OnRefresh: TNotifyEvent read FOnRefresh write FOnRefresh;
    property OnAddRecent: TNotifyEvent read FOnAddRecent write FOnAddRecent;
    property OnSongSaved: TSongSavedEvent read FOnSongSaved write FOnSongSaved;
    property OnTitleChanged: TStringEvent read FOnTitleChanged write FOnTitleChanged;
    property OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;
    property OnICYReceived: TIntegerEvent read FOnICYReceived write FOnICYReceived;
    property OnURLsReceived: TNotifyEvent read FOnURLsReceived write FOnURLsReceived;
    property OnTitleAllowed: TTitleAllowedEvent read FOnTitleAllowed write FOnTitleAllowed;

    property OnPlay: TNotifyEvent read FOnPlay write FOnPlay;
    property OnPause: TNotifyEvent read FOnPause write FOnPause;
    property OnStop: TNotifyEvent read FOnStop write FOnStop;
  end;

implementation

{ TICEClient }

constructor TICEClient.Create(StartURL: string);
begin
  inherited Create;
  Initialize;
  FEntry.StartURL := Trim(StartURL);
end;

constructor TICEClient.Create(Name, StartURL: string);
begin
  Initialize;
  FEntry.StartURL := Trim(StartURL);
  FEntry.Name := Trim(Name);
end;

constructor TICEClient.Create(Entry: TStreamEntry);
begin
  Initialize;
  FEntry.Assign(Entry);
end;

procedure TICEClient.Initialize;
begin
  Players.AddPlayer(Self);

  FDebugLog := TDebugLog.Create;
  FProcessingList := TProcessingList.Create;

  FEntry := TStreamEntry.Create;
  FEntry.Settings.Assign(AppGlobals.StreamSettings);

  FKilled := False;
  FState := csStopped;
  FTitle := '';
  FSpeed := 0;
  FContentType := '';
  FFilename := '';
  FRedirectedURL := '';
  FURLsIndex := -1;
  FRetries := 0;
end;

procedure TICEClient.Kill;
begin
  FKilled := True;
  Disconnect;
end;

procedure TICEClient.StartPlay;
begin
  Connect;

  if FICEThread <> nil then
  begin
    FICEThread.StartPlay;
    if Assigned(FOnPlay) then
      FOnPlay(Self);
  end;
end;

procedure TICEClient.PausePlay;
begin
  if FICEThread <> nil then
  begin
    FICEThread.PausePlay;
    if Assigned(FOnPause) then
      FOnPause(Self);
  end;
end;

procedure TICEClient.StopPlay;
begin
  if FICEThread <> nil then
  begin
    FICEThread.StopPlay;

    if Assigned(FOnStop) then
      FOnStop(Self);

    if (not FICEThread.Recording) and (not FICEThread.Playing) and (not FICEThread.Paused) then
    begin
      Disconnect;
    end;
  end;
end;

procedure TICEClient.StartRecording;
begin
  Connect;

  if FICEThread <> nil then
    FICEThread.StartRecording;
end;

procedure TICEClient.StopRecording;
begin
  FFilename := '';
  if FICEThread <> nil then
  begin
    FICEThread.StopRecording;

    if (not FICEThread.Recording) and (not FICEThread.Playing) then
    begin
      Disconnect;
    end;
  end;
end;

procedure TICEClient.Connect;
begin
  FRetries := 0;
  Start;
end;

procedure TICEClient.Start;
begin
  if FICEThread <> nil then
    Exit;

  FState := csConnecting;
  if Assigned(FOnRefresh) then
    FOnRefresh(Self);

  FCurrentURL := GetURL;
  FICEThread := TICEThread.Create(FCurrentURL);
  FICEThread.OnDebug := ThreadDebug;
  FICEThread.OnTitleChanged := ThreadTitleChanged;
  FICEThread.OnSongSaved := ThreadSongSaved;
  FICEThread.OnNeedSettings := ThreadNeedSettings;
  FICEThread.OnStateChanged := ThreadStateChanged;
  FICEThread.OnSpeedChanged := ThreadSpeedChanged;
  FICEThread.OnBeforeEnded := ThreadBeforeEnded;
  FICEThread.OnTerminate := ThreadTerminated;
  FICEThread.OnAddRecent := ThreadAddRecent;
  FICEThread.OnTitleAllowed := ThreadTitleAllowed;

  // Das muss hier so fr�h sein, wegen z.B. RetryDelay - das hat der Stream n�mlich nicht,
  // wenn z.B. beim Verbinden was daneben geht.
  ThreadNeedSettings(FICEThread);

  FICEThread.Start;
end;

destructor TICEClient.Destroy;
begin
  Players.RemovePlayer(Self);
  FEntry.Free;
  FDebugLog.Free;
  FreeAndNil(FProcessingList);
  inherited;
end;

procedure TICEClient.Disconnect;
begin
  FState := csStopping;

  if FICEThread = nil then
    Exit;

  FRetries := 0;
  FICEThread.StopPlay;
  FICEThread.Terminate;
  if Assigned(FOnRefresh) then
    FOnRefresh(Self);
end;

function TICEClient.FGetActive: Boolean;
begin
  Result := ((FState <> csStopped) and (FState <> csIOError)) or (FProcessingList.Count > 0); { or (C > 0); }
end;

function TICEClient.FGetRecording: Boolean;
begin
  Result := False;
  if FICEThread = nil then
    Exit;

  Result := ((FState <> csStopped) and (FState <> csIOError)) and FICEThread.Recording;
end;

function TICEClient.FGetPaused: Boolean;
begin
  Result := False;
  if FICEThread = nil then
    Exit;

  Result := ((FState <> csStopped) and (FState <> csIOError)) and FICEThread.Paused;
end;

function TICEClient.FGetPlaying: Boolean;
begin
  Result := False;
  if FICEThread = nil then
    Exit;

  Result := ((FState <> csStopped) and (FState <> csIOError)) and FICEThread.Playing;
end;

function TICEClient.GetURL: string;
begin
  if FRedirectedURL <> '' then
  begin
    Result := FRedirectedURL;
    FRedirectedURL := '';
    Exit;
  end;

  if (FURLsIndex = -1) and (FEntry.StartURL <> '') then
  begin
    Result := FEntry.StartURL;
    FURLsIndex := 0;
    Exit;
  end;

  if FEntry.URLs.Count > 0 then
  begin
    if FURLsIndex >= FEntry.URLs.Count then
    begin
      if (FEntry.StartURL <> '') and (Pos('streamwriter.', LowerCase(FEntry.StartURL)) = 0) then
      begin
        Result := FEntry.StartURL;
        FURLsIndex := 0;
        Exit;
      end else
        FURLsIndex := 0;
    end;
    if FURLsIndex = -1 then
      FURLsIndex := 0;
    Result := FEntry.URLs[FURLsIndex];
    Inc(FURLsIndex);
  end else
    Result := FEntry.StartURL;
end;

procedure TICEClient.ThreadAddRecent(Sender: TSocketThread);
begin
  FEntry.Name := FICEThread.RecvStream.StreamName;
  if FEntry.Name = '' then
    FEntry.Name := FEntry.StartURL;

  FEntry.StreamURL := FICEThread.RecvStream.StreamURL;

  FContentType := FICEThread.RecvStream.ContentType;
  if FICEThread.RecvStream.BitRate > 0 then
    FEntry.Bitrate := FICEThread.RecvStream.BitRate;
  if FICEThread.RecvStream.Genre <> '' then
    FEntry.Genre := FICEThread.RecvStream.Genre;

  if FICEThread.RecvStream.AudioType = atMPEG then
    FEntry.AudioType := 'MP3'
  else if FICEThread.RecvStream.AudioType = atAAC then
    FEntry.AudioType := 'AAC'
  else
    FEntry.AudioType := '';

  if Assigned(FOnAddRecent) then
    FOnAddRecent(Self);
end;

procedure TICEClient.ThreadDebug(Sender: TSocketThread);
var
  T: TDebugTypes;
  Level: TDebugLevels;
begin
  T := TDebugTypes(FICEThread.DebugType);
  Level := TDebugLevels(FICEThread.DebugLevel);

  WriteDebug(FICEThread.DebugMsg, FICEThread.DebugData, T, Level);
end;

procedure TICEClient.ThreadBeforeEnded(Sender: TSocketThread);
begin
  inherited;

  try
    if FICEThread.RecvStream.HeaderType = 'http' then
    begin
      if FICEThread.RecvStream.RedirURL <> '' then
      begin
        FRedirectedURL := FICEThread.RecvStream.RedirURL;
      end else if ParsePlaylist then
      begin
        {$IFDEF DEBUG}
        WriteDebug(_('Playlist parsed'), FEntry.URLs.Text, dtMessage, dlNormal);
        {$ELSE}
        WriteDebug(_('Playlist parsed'), dtMessage, dlNormal);
        {$ENDIF}

        // ClientManager pr�ft, ob es in einem anderen Client schon eine der URLs gibt.
        // Wenn ja, t�tet der ClientManager den neu hinzugef�gten Client.
        if Assigned(FOnURLsReceived) then
          FOnURLsReceived(Self);
      end else
      begin
        raise Exception.Create(_('Response was HTTP, but without supported playlist or redirect'));
      end;
    end else
    begin
      // Am Ende noch die Bytes die nicht mitgeteilt wurden durchreichen
      FEntry.BytesReceived := FEntry.BytesReceived + FICEThread.Speed;
      if Assigned(FOnICYReceived) then
        FOnICYReceived(Self, FICEThread.Speed);
    end;
  except
    on E: Exception do
    begin
      WriteDebug(Format(_('Error: %s'), [E.Message]), '', dtError, dlNormal);

      // REMARK: Das hier ist Mist.
      // Sollte alles in den Thread, diese ganze Procedure in der dieser Kommentar steht.
      // Mit diesem Schmiermerker 'SleepTime' sage ich dem Thread jetzt 'Warte, bitte.' - aber das ist
      // irgendwie unsch�n so.
      if (FRetries < FEntry.Settings.MaxRetries) and (FEntry.Settings.MaxRetries > 0) then
        FICEThread.SleepTime := FICEThread.RecvStream.Settings.RetryDelay;

      FState := csRetrying;
      if Assigned(FOnRefresh) then
        FOnRefresh(Self);
    end;
  end;
end;

procedure TICEClient.ThreadNeedSettings(Sender: TSocketThread);
begin
  FICEThread.SetSettings(FEntry.Settings, FAutoRemove, FStopAfterSong, FRecordTitle);
end;

procedure TICEClient.ThreadSongSaved(Sender: TSocketThread);
var
  Data: TPluginProcessInformation;
  Entry: TProcessingEntry;
begin
  FEntry.SongsSaved := FEntry.SongsSaved + 1;

  try
    // Pluginbearbeitung starten
    Data.Filename := FICEThread.RecvStream.SavedFilename;
    Data.Station := FEntry.Name;
    Data.Artist := FICEThread.RecvStream.SavedArtist;
    Data.Title := FICEThread.RecvStream.SavedTitle;
    Data.TrackNumber := FEntry.SongsSaved;
    Data.Filesize := FICEThread.RecvStream.SavedSize;
    Data.Length := FICEThread.RecvStream.SavedLength;
    Data.WasCut := FICEThread.RecvStream.SavedWasCut;
    Data.FullTitle := FICEThread.RecvStream.SavedFullTitle;
    Data.StreamTitle := FICEThread.RecvStream.SavedStreamTitle;

    if not FKilled then
    begin
      Entry := AppGlobals.PluginManager.ProcessFile(Data);
      if Entry <> nil then
      begin
        WriteDebug(Format('Plugin "%s" starting.', [Entry.ActiveThread.Plugin.Name]), dtMessage, dlDebug);

        Entry.ActiveThread.OnTerminate := PluginThreadTerminate;
        Entry.ActiveThread.Resume;
        FProcessingList.Add(Entry);
      end;
    end;

    if FProcessingList.Count = 0 then
    begin
      // Wenn kein Plugin die Verarbeitung �bernimmt, gilt die Datei
      // jetzt schon als gespeichert. Ansonsten macht das PluginThreadTerminate.
      if Assigned(FOnSongSaved) then
        FOnSongSaved(Self, FICEThread.RecvStream.SavedFilename, FICEThread.RecvStream.SavedStreamTitle,
          FICEThread.RecvStream.SavedSize, FICEThread.RecvStream.SavedLength, FICEThread.RecvStream.SavedWasCut, FICEThread.RecvStream.SavedFullTitle);
      if Assigned(FOnRefresh) then
        FOnRefresh(Self);

      if FAutoRemove then
      begin
        Kill;
        if Assigned(FOnDisconnected) and (FICEThread = nil) then
          FOnDisconnected(Self);
      end;
    end;
  except
    on E: Exception do
    begin
      WriteDebug(Format(_('Could not postprocess song: %s'), [E.Message]), dtError, dlNormal);
    end;
  end;

  if FStopAfterSong then
  begin
    StopRecording;
    FStopAfterSong := False;
  end;
end;

procedure TICEClient.PluginThreadTerminate(Sender: TObject);
var
  i: Integer;
  Processed: Boolean;
  Entry: TProcessingEntry;
begin
  for i := 0 to FProcessingList.Count - 1 do
  begin
    if FProcessingList[i].ActiveThread = Sender then
    begin
      Entry := FProcessingList[i];

      case Entry.ActiveThread.Result of
        arWin:
          WriteDebug(Format(_('Plugin "%s" successfully finished.'), [Entry.ActiveThread.Plugin.Name]), dtMessage, dlNormal);
          {
          if Entry.ActiveThread.Output <> '' then
            WriteDebug(Format(_('Plugin "%s" successfully finished.'), [Entry.ActiveThread.Plugin.Name]), Entry.ActiveThread.Output, dlNormal)
          else
            WriteDebug(Format(_('Plugin "%s" successfully finished.'), [Entry.ActiveThread.Plugin.Name]), dlNormal);
          }
        arTimeout:
          WriteDebug(Format(_('Plugin "%s" timed out.'), [Entry.ActiveThread.Plugin.Name]), dtError, dlNormal);
          {
          if Entry.ActiveThread.Output <> '' then
            WriteDebug(Format(_('Plugin "%s" timed out.'), [Entry.ActiveThread.Plugin.Name]), Entry.ActiveThread.Output, dlNormal)
          else
            WriteDebug(Format(_('Plugin "%s" timed out.'), [Entry.ActiveThread.Plugin.Name]), dlNormal);
          }
        arFail:
          WriteDebug(Format(_('Plugin "%s" failed.'), [Entry.ActiveThread.Plugin.Name]), dtError, dlNormal);
      end;

      // Eine externe App k�nnte das File gel�scht haben
      if Entry.Data.Filesize <> High(UInt64) then // GetFileSize = Int64 => -1
      begin
        Processed := AppGlobals.PluginManager.ProcessFile(Entry);
        if Processed then
        begin
          WriteDebug(Format('Plugin "%s" starting.', [Entry.ActiveThread.Plugin.Name]), dtMessage, dlDebug);

          Entry.ActiveThread.OnTerminate := PluginThreadTerminate;
          Entry.ActiveThread.Resume;
        end else
        begin
          WriteDebug('All plugins done', dtMessage, dlDebug);

          if Assigned(FOnSongSaved) then
            FOnSongSaved(Self, Entry.Data.Filename, Entry.Data.StreamTitle, Entry.Data.Filesize, Entry.Data.Length, Entry.Data.WasCut, Entry.Data.FullTitle);
          if Assigned(FOnRefresh) then
            FOnRefresh(Self);

          Entry.Free;
          FProcessingList.Delete(i);
        end;
      end else
      begin
        WriteDebug(_('An external application or plugin has deleted the saved file.'), dtError, dlNormal);

        Entry.Free;
        FProcessingList.Delete(i);
      end;

      if FAutoRemove then
      begin
        if Assigned(FOnDisconnected) and (FICEThread = nil) and (FProcessingList.Count = 0) then
        begin
          Kill;
          FOnDisconnected(Self);
        end;
      end;

      Break;
    end;
  end;
end;

procedure TICEClient.ThreadSpeedChanged(Sender: TSocketThread);
begin
  if FICEThread.RecvStream.HeaderType = 'icy' then
  begin
    FEntry.BytesReceived := FEntry.BytesReceived + FICEThread.Speed;
    FSpeed := FICEThread.Speed;

    if Assigned(FOnICYReceived) then
      FOnICYReceived(Self, FICEThread.Speed);
  end;
end;

procedure TICEClient.ThreadTitleAllowed(Sender: TSocketThread);
var
  A: Boolean;
  M: string;
  F: Integer;
begin
  if Assigned(FOnTitleAllowed) then
  begin
    A := True;
    FOnTitleAllowed(Self, FICEThread.RecvStream.SaveAllowedTitle, A, M, F);
    FICEThread.RecvStream.SaveAllowed := A;
    FICEThread.RecvStream.SaveAllowedMatch := M;
    FICEThread.RecvStream.SaveAllowedFilter := F;
  end;
end;

procedure TICEClient.ThreadTitleChanged(Sender: TSocketThread);
var
  Format: string;
begin
  if (FICEThread.RecvStream.Title <> '') and Playing and (not Paused) and AppGlobals.DisplayPlayNotifications then
  begin
    TfrmNotification.Act(FICEThread.RecvStream.Title, FEntry.Name);
  end;

  FTitle := FICEThread.RecvStream.Title;
  if Assigned(FOnTitleChanged) then
    FOnTitleChanged(Self, FICEThread.RecvStream.Title);
  if Assigned(FOnRefresh) then
    FOnRefresh(Self);

  if (FICEThread.RecvStream.FullTitleFound) and (not FAutoRemove) and (FRecordTitle = '') then
    if AppGlobals.SubmitStreamInfo then
    begin
      if FICEThread.RecvStream.AudioType = atMPEG then
        Format := 'mp3'
      else if FICEThread.RecvStream.AudioType = atAAC then
        Format := 'aac'
      else
        raise Exception.Create('');

      HomeComm.TitleChanged(Entry.Name, FTitle, FCurrentURL, Entry.StartURL, Format,
        Entry.BitRate, Entry.URLs);
    end;
end;

procedure TICEClient.ThreadStateChanged(Sender: TSocketThread);
begin
  if FState <> csStopping then
  begin
    case FICEThread.State of
      tsRecording:
        begin
          FFilename := FICEThread.RecvStream.Filename;
          FState := csConnected;
        end;
      tsRetrying:
        begin
          FTitle := '';
          FState := csRetrying;
        end;
      tsIOError:
        begin
          FState := csIOError;
        end;
    end;
    if Assigned(FOnRefresh) then
      FOnRefresh(Self);
  end;

  // Das muss, damit bei Fehlern mit Daten, die BASS nicht parsen kann, beendet wird.
  // Der ICEPlayer wirft bei PushData() eine Exception wenn das so ist.
  if (not FICEThread.Recording) and (not FICEThread.Playing) then
  begin
    Disconnect;
  end;
end;

procedure TICEClient.ThreadTerminated(Sender: TObject);
var
  MaxRetries: Integer;
  DiedThread: TICEThread;
begin
  if FICEThread <> Sender then
    Exit;

  DiedThread := TICEThread(Sender);

  FICEThread := nil;
  FTitle := '';
  FSpeed := 0;
  FFilename := '';
  MaxRetries := FEntry.Settings.MaxRetries;

  if DiedThread.RecvStream.HaltClient or AutoRemove then
  begin
    if FProcessingList.Count = 0 then
      Kill
    else
      Disconnect;
    if Assigned(FOnDisconnected) and (FICEThread = nil) and (FProcessingList.Count = 0) then
      FOnDisconnected(Self);
    Exit;
  end;

  if FStopAfterSong then
  begin
    StopAfterSong := False;
    StopRecording;
  end;

  if (FState <> csStopping) and (FState <> csIOError) then
  begin
    if (FRetries >= MaxRetries) and (MaxRetries > 0) then
    begin
      WriteDebug(Format(_('Retried %d times, stopping'), [MaxRetries]), dtError, dlNormal);
      FState := csStopped;
    end else
    begin
      Start;
      if DiedThread.Playing then
        FICEThread.StartPlay;
      if DiedThread.Paused then
        FICEThread.PausePlay;
      if DiedThread.Recording then
        FICEThread.StartRecording;
    end;
    if FRedirectedURL = '' then
      Inc(FRetries);
  end else
    FState := csStopped;

  if Assigned(FOnRefresh) then
    FOnRefresh(Self);

  if Assigned(FOnDisconnected) and (FICEThread = nil) then
    FOnDisconnected(Self);
end;

procedure TICEClient.WriteDebug(Text, Data: string; T: TDebugTypes; Level: TDebugLevels);
begin
  {$IFNDEF DEBUG}
  if Level <> dlNormal then
    Exit;
  {$ENDIF}
  FDebugLog.Add(TDebugEntry.Create(Text, Data, T, Level));
  if Assigned(FOnDebug) then
    FOnDebug(Self);
end;

procedure TICEClient.WriteDebug(Text: string; T: TDebugTypes; Level: TDebugLevels);
begin
  WriteDebug(Text, '', T, Level);
end;

function TICEClient.ParsePlaylist: Boolean;
  procedure ParseLine(Line: string; URLs: TStringList);
  var
    Host, URLData: string;
    Port: Integer;
    PortDetected: Boolean;
  begin
    if ParseURL(Line, Host, Port, URLData, PortDetected) then
    begin
      if not PortDetected then
      begin
        // Es gibt keinen Standard scheinbar - beide nehmen.
        URLs.Add('http://' + Host + ':80' + URLData);
        URLs.Add('http://' + Host + ':6666' + URLData);
      end else
      begin
        URLs.Add('http://' + Host + ':' + IntToStr(Port) + URLData);
        //if Port <> 80 then
        //  FURLs.Add(Host + ':80' + URLData);
      end;
    end;
  end;
var
  Offset, Offset2, Offset3: Integer;
  Line, Data: string;
  URLs: TStringList;
begin
  URLs := TStringList.Create;
  try
    Offset := 1;
    Data := string(FICEThread.RecvStream.RecvStream.ToString);
    if (Copy(LowerCase(Data), 1, 10) = '[playlist]') or
       (Pos('audio/x-scpls', FICEThread.RecvStream.ContentType) > 0) or
       (Pos('application/pls+xml', FICEThread.RecvStream.ContentType) > 0) then // .pls
    begin
      while True do
      begin
        Offset2 := PosEx(#10, Data, Offset);
        if Offset2 > 0 then
          Line := Trim(Copy(Data, Offset, Offset2 - Offset))
        else
          Line := Trim(Copy(Data, Offset, Length(Data)));

        Offset := Offset2 + 1;

        if Copy(LowerCase(Line), 1, 4) = 'file' then
        begin
          Offset3 := Pos('=', Line);
          if Offset3 > 0 then
          begin
            Line := Trim(Copy(Line, Offset3 + 1, Length(Line) - Offset3));
            if (Line <> '') then
              ParseLine(Line, URLs);
          end;
        end;

        if Offset2 = 0 then
          Break;
      end;
    end else if (LowerCase(Copy(Data, 1, 7)) = '#extm3u') or
                (Pos('audio/x-mpegurl', FICEThread.RecvStream.ContentType) > 0) or
                (Pos('audio/mpegurl', FICEThread.RecvStream.ContentType) > 0) then // .m3u
    begin
      while True do
      begin
        Offset2 := PosEx(#10, Data, Offset);
        if Offset2 > 0 then
          Line := Trim(Copy(Data, Offset, Offset2 - Offset))
        else
          Line := Trim(Copy(Data, Offset, Length(Data)));

        Offset := Offset2 + 1;

        if (Length(Line) >= 1) and (Line[1] <> '#') then
          ParseLine(Line, URLs);

        if Offset2 = 0 then
          Break;
      end;
    end else
    begin
      // Im Notfall alles was empfangen wurde als URLs interpretieren.
      // Siehe z.B. http://www.rockantenne.de/webradio/rockantenne.m3u

      // Das ist raus, weil ich oben noch die Content-Types abfrage.
      // Damit sollte dieser Mist hier �ber sein.

      {
      if FICEThread.RecvStream.Size < 102400 then
      begin
        while True do
        begin
          Offset2 := PosEx(#10, Data, Offset);
          if Offset2 > 0 then
            Line := Trim(Copy(Data, Offset, Offset2 - Offset))
          else
            Line := Trim(Copy(Data, Offset, Length(Data)));

          Offset := Offset2 + 1;

          if (Length(Line) >= 1) and (Line[1] <> '#') then
            ParseLine(Line);

          if Offset2 = 0 then
            Break;
        end;
      end;
      }
    end;
    Result := URLs.Count > 0;
    if Result then
    begin
      Entry.URLs.Assign(URLs);
      FURLsIndex := 0;
    end;
  finally
    URLs.Free;
  end;
end;

procedure TICEClient.SetSettings(Settings: TStreamSettings);
begin
  FEntry.Settings.Assign(Settings);
end;

procedure TICEClient.SetVolume(Vol: Integer);
begin
  if FICEThread <> nil then
    FICEThread.SetVolume(Vol);
end;

{ TDebugEntry }

constructor TDebugEntry.Create(Text, Data: string; T: TDebugTypes; Level: TDebugLevels);
begin
  Self.Text := Text;
  Self.Data := Data;
  Self.T := T;
  Self.Level := Level;
  Self.Time := Now;
end;

{ TURLList }

function TURLList.Add(const S: string): Integer;
var
  i, Port: Integer;
  Host, Data: string;
  S2: string;
begin
  Result := -1;
  try
    S2 := s;
    if not ParseURL(S2, Host, Port, Data) then
      Exit;
  except
    Exit;
  end;
  if Length(Host) <= 3 then
    Exit;
  for i := 0 to Count - 1 do
    if LowerCase(S2) = LowerCase(Self[i]) then
      Exit;
  Result := inherited;
end;

{ TDebugLog }

procedure TDebugLog.Notify(const Item: TDebugEntry;
  Action: TCollectionNotification);
var
  i: Integer;
begin
  inherited;
  if (Action = cnAdded) and (Count > 1000) then
    for i := Count - 500 downto 0 do
      Delete(i);
end;

end.

