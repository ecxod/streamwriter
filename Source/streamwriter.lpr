{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2023 Alexander Nottelmann

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

program streamwriter;

uses
  AppData,
  AppDataBase,
  AppMessages,
  AppStartup,
  Classes,
  DynBass,
  Forms,
  Functions,
  Interfaces,
  JwaWinNT,
  LanguageObjects,
  Main,
  MessageBus,
  PlayerManager,
  SharedData,
  Patches,
  Sockets,
  SplashThread,
  SysUtils,
  Windows,
  WinSock2,
  Wizard;

{$SetPEFlags IMAGE_FILE_LARGE_ADDRESS_AWARE}
{$SetPEFlags IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP}
{$SetPEOptFlags IMAGE_DLLCHARACTERISTICS_NX_COMPAT}
{$SetPEOptFlags IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE}

{$R *.res}
{$R ..\Resources\language.res}
{$R ..\SubModules\fpc-common\res\language_common.res}
{$R ..\SubModules\fpc-common\res\lang_icons.rc}
{$R ..\SubModules\fpc-common\res\images.rc}

procedure UnhandledException(Obj: TObject; Addr: Pointer; FrameCount: Longint; Frames: PPointer);
var
  i: LongInt;
  Message: string;
begin
  Message := 'An unhandled exception occurred at %s'#13#10.Format([Trim(SysBacktraceStr(Addr))]);
  if Obj is Exception then
    Message += '%s: %s'#13#10.Format([Exception(Obj).ClassName, Exception(Obj).Message]);

  Message += '  %s'.Format([StringReplace(Trim(BackTraceStrFunc(Addr)), '  ', ' ', [rfReplaceAll])]);
  for i := 0 to FrameCount - 1 do
    Message += #13#10'  %s'.Format([StringReplace(Trim(BackTraceStrFunc(Frames[i])), '  ', ' ', [rfReplaceAll])]);

  TFunctions.MsgBox(Message, 'Error', MB_ICONERROR);
end;

var
  i: Integer;
  HideMain, Found: Boolean;
  frmStreamWriterMain: TfrmStreamWriterMain;
begin
  IsMultiThread := True;

  ExceptProc := @UnhandledException;
  SetErrorMode(SEM_FAILCRITICALERRORS);

  Bass := nil;
  try
    if not InitWinsock then
      Exit;

    HideMain := False;
    for i := 0 to ParamCount do
      if ParamStr(i) = '-minimize' then
      begin
        HideMain := True;
        Break;
      end;

    // Initialize the AppGlobals object without loading any settings.
    // If we need to show the profile selection window, this would make no sense.
    try
      CreateAppData;
    except
      on EAlreadyRunning do
        Exit;
    end;
    MsgBus := TSWMessageBus.Create;

    Application.Title := AppGlobals.AppName;
    Application.CaptureExceptions := False;
    Application.Initialize;

    if not InitAppStageOne then
      Exit;

    // Basic initialization
    if not InitAppDataStageOne then
      Exit;

    InitPlayerManager;

    if (AppGlobals.ShowSplashScreen) and (AppGlobals.FirstStartShown) and (AppGlobals.WasSetup) and (not TFunctions.IsVersionNewer(AppGlobals.LastUsedVersion, AppGlobals.AppVersion, False)) and
      (not HideMain) and (not AppGlobals.InstallUpdateOnStart) then
      TSplashThread.Create('Window', 'SPLASH', AppGlobals.Codename, AppGlobals.AppVersion.AsString, AppGlobals.GitSHA,
        AppGlobals.MainLeft, AppGlobals.MainTop, AppGlobals.MainWidth, AppGlobals.MainHeight);

    TSocketThread.LoadCertificates('CERTIFICATES');

    // Now load everything from datafiles
    if not InitAppDataStageTwo then
      Exit;

    // Initialize BASS, quit application on error
    Bass := TBassLoader.Create;
    if not Bass.InitializeBass(0, True, False, False, False) then
    begin
      TFunctions.MsgBox(_('The BASS library or it''s plugins could not be extracted/loaded. Without these libraries streamWriter cannot record/playback streams. Try to get help at streamWriter''s board.'), _('Error'), MB_ICONERROR);
      Exit;
    end;

    Found := False;
    for i := 0 to Bass.Devices.Count - 1 do
      if Bass.Devices[i].ID = AppGlobals.SoundDevice then
      begin
        Found := True;
        Break;
      end;
    if not Found then
      for i := 0 to Bass.Devices.Count - 1 do
        if Bass.Devices[i].IsDefault then
        begin
          AppGlobals.SoundDevice := Bass.Devices[i].ID;
          Break;
        end;

    Application.CreateForm(TmodSharedData, modSharedData);

    // Create the main form if everything is setup
    if InitAppStageTwo(TfrmWizard) and AppGlobals.WasSetup then
    begin
      if AppGlobals.Tray and HideMain then
        Application.ShowMainForm := False;

      Application.CreateForm(TfrmStreamWriterMain, frmStreamWriterMain);
    end;

    Application.Run;
  finally
    WSACleanup;
    TSocketThread.FreeCertificates;
    if Bass <> nil then
      Bass.Free;
  end;
end.
