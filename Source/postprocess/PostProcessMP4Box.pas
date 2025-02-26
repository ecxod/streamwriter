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

unit PostProcessMP4Box;

interface

uses
  AddonMP4Box,
  AudioFunctions,
  Classes,
  DataManager,
  Functions,
  Generics.Collections,
  LanguageObjects,
  Logging,
  PostProcess,
  SysUtils;

type
  TPostProcessMP4BoxThread = class(TPostProcessThreadBase)
  private
    FMP4BoxPath: string;
  protected
    procedure Execute; override;
  public
    constructor Create(Data: PPostProcessInformation; Addon: TPostProcessBase);
  end;

  TPostProcessMP4Box = class(TInternalPostProcess)
  private
  protected
    function FGetName: string; override;
    function FGetHelp: string; override;
  public
    constructor Create;
    destructor Destroy; override;
    function ShowInitMessage(Handle: THandle): Boolean; override;
    function CanProcess(Data: PPostProcessInformation; ProcessingList: TList<TPostprocessBase>): Boolean; override;
    function ProcessFile(Data: PPostProcessInformation): TPostProcessThreadBase; override;
    function Copy: TPostProcessBase; override;
    procedure Assign(Source: TPostProcessBase); override;
    procedure Load(Stream: TStream; Version: Integer); override;
    procedure Save(Stream: TMemoryStream); override;

    function MP4BoxMux(InFile, OutFile: string; TerminateFlag: PByteBool): TActResults;
  end;

implementation

uses
  AppData,
  ConfigureSoX;

{ TPostProcessMP4BoxThread }

constructor TPostProcessMP4BoxThread.Create(Data: PPostProcessInformation; Addon: TPostProcessBase);
begin
  inherited Create(Data, Addon);

  FMP4BoxPath := TAddonMP4Box(AppGlobals.AddonManager.Find(TAddonMP4Box)).MP4BoxEXEPath;
end;

procedure TPostProcessMP4BoxThread.Execute;
var
  OutFile, MovedFileName: string;
begin
  inherited;

  if LowerCase(ExtractFileExt(FData.Filename)) <> '.aac' then
  begin
    FResult := arImpossible;
    Exit;
  end;

  OutFile := TFunctions.RemoveFileExt(FData.Filename) + '_mux.m4a';
  FResult := TPostProcessMP4Box(PostProcessor).MP4BoxMux(FData.Filename, OutFile, @Terminated);
  case FResult of
    arWin:
    begin
      MovedFileName := TFunctions.RemoveFileExt(FData.Filename) + '.m4a';
      if RenameFile(OutFile, MovedFileName) then
      begin
        DeleteFile(FData.Filename);
        FData.Filename := MovedFileName;
        FData.Filesize := TFunctions.GetFileSize(MovedFileName);
      end;
    end;
    arFail: ;
    arTimeOut: ;
    arImpossible: ;
  end;

  DeleteFile(OutFile);
end;

{ TPostProcessMP4Box }

procedure TPostProcessMP4Box.Assign(Source: TPostProcessBase);
begin
  inherited;

end;

function TPostProcessMP4Box.CanProcess(Data: PPostProcessInformation; ProcessingList: TList<TPostprocessBase>): Boolean;
var
  OutputFormat: TAudioTypes;
begin
  OutputFormat := TEncoderSettings(Data.EncoderSettings).AudioType;
  if OutputFormat = atNone then
    OutputFormat := FilenameToFormat(Data.Filename);

  Result := (OutputFormat = atAAC) and FGetDependenciesMet;
end;

function TPostProcessMP4Box.Copy: TPostProcessBase;
begin
  Result := TPostProcessMP4Box.Create;

  Result.Active := FActive;
  Result.Order := FOrder;
  Result.OnlyIfCut := FOnlyIfCut;

  Result.Assign(Self);
end;

constructor TPostProcessMP4Box.Create;
begin
  inherited;

  //  FNeededAddons.Add(TAddonMP4Box);

  FCanConfigure := False;
  FGroupID := 1;
  FOrder := 1001;

  FPostProcessType := ptMP4Box;
end;

function TPostProcessMP4Box.MP4BoxMux(InFile, OutFile: string; TerminateFlag: PByteBool): TActResults;
var
  CmdLine, MP4BoxPath: string;
  Output: AnsiString;
  EC: DWORD;
begin
  Result := arFail;

  MP4BoxPath := (AppGlobals.AddonManager.Find(TAddonMP4Box) as TAddonMP4Box).MP4BoxEXEPath;

  CmdLine := '"' + MP4BoxPath + '" -add "' + InFile + '" "' + OutFile + '"';

  case TFunctions.RunProcess(CmdLine, ExtractFilePath(MP4BoxPath), 300000, Output, EC, TerminateFlag, True) of
    rpWin:
      if FileExists(OutFile) and (EC = 0) then
        Result := arWin;
    rpTimeout:
      Result := arTimeout;
  end;

  if Result <> arWin then
    DeleteFile(OutFile);
end;

destructor TPostProcessMP4Box.Destroy;
begin

  inherited;
end;

function TPostProcessMP4Box.FGetHelp: string;
begin
  Result := _('This postprocessor converts recorded songs from AAC to M4A.');
end;

function TPostProcessMP4Box.FGetName: string;
begin
  Result := _('Convert AAC to M4A');
end;

procedure TPostProcessMP4Box.Load(Stream: TStream; Version: Integer);
begin
  inherited;

end;

function TPostProcessMP4Box.ProcessFile(Data: PPostProcessInformation): TPostProcessThreadBase;
begin
  Result := TPostProcessMP4BoxThread.Create(Data, Self);
end;

procedure TPostProcessMP4Box.Save(Stream: TMemoryStream);
begin
  inherited;

end;

function TPostProcessMP4Box.ShowInitMessage(Handle: THandle): Boolean;
begin
  Result := inherited;
end;

end.
