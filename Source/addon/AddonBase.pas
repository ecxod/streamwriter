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

unit AddonBase;

interface

uses
  AudioFunctions,
  Classes,
  Functions,
  SysUtils,
  Windows;

type

  { TAddonBase }

  TAddonBase = class
  private
  protected
    FCopied: Boolean;
    FFilesDir: string;
    FCanConfigure: Boolean;
    FOrder: Integer;
    FOnlyIfCut: Boolean;

    FDownloadPackage: string;
    FDownloadName: string;
    FHasInitMessage: Boolean;

    FFilenames: TStringList;
    FNeededAddons: TList;
    FNeededVersion: TAppVersion;

    function FGetFilesExtracted: Boolean; virtual;
    function FGetPackageDownloaded: Boolean; virtual;
    function FGetVersionOkay: Boolean;
    function FGetDependenciesMet: Boolean; virtual;

    function FGetName: string; virtual;
    function FGetHelp: string; virtual;

    procedure DeleteFiles; virtual;
  public
    constructor Create;
    destructor Destroy; override;

    function Copy: TAddonBase; virtual; abstract;
    procedure Assign(Source: TAddonBase); virtual;

    function ExtractFiles: Boolean; virtual;

    function ShowInitMessage(Handle: THandle): Boolean; virtual;

    function CanEncode(AudioType: TAudioTypes): Boolean; virtual;

    property Copied: Boolean read FCopied write FCopied;

    property Name: string read FGetName;
    property Help: string read FGetHelp;

    property DownloadPackage: string read FDownloadPackage;
    property DownloadName: string read FDownloadName;
    property NeededAddons: TList read FNeededAddons;

    property FilesExtracted: Boolean read FGetFilesExtracted;
    property PackageDownloaded: Boolean read FGetPackageDownloaded;
    property VersionOkay: Boolean read FGetVersionOkay;
    property DependenciesMet: Boolean read FGetDependenciesMet;
    property HasInitMessage: Boolean read FHasInitMessage;
  end;

implementation

uses
  AppData;

{ TAddonBase }

procedure TAddonBase.Assign(Source: TAddonBase);
begin
  FFilenames.Assign(Source.FFilenames);
end;

function TAddonBase.CanEncode(AudioType: TAudioTypes): Boolean;
begin
  Result := False;
end;

constructor TAddonBase.Create;
begin
  inherited;

  FFilenames := TStringList.Create;
  FNeededAddons := TList.Create;
  FNeededVersion := TFunctions.ParseVersion('1.0.0.0');
end;

procedure TAddonBase.DeleteFiles;
var
  i: Integer;
begin
  if FCopied then
    Exit;

  for i := 0 to FFilenames.Count - 1 do
    SysUtils.DeleteFile(ConcatPaths([FFilesDir, FFilenames[i]]));
  try
    RemoveDir(FFilesDir);
  except
  end;
end;

destructor TAddonBase.Destroy;
begin
  DeleteFiles;
  FFilenames.Free;
  FNeededAddons.Free;

  inherited;
end;

function TAddonBase.ExtractFiles: Boolean;
var
  i: Integer;
  H: THandle;
  Res: TResourceStream;
  LibraryPath: string;
begin
  if FilesExtracted then
    Exit(True);

  Result := False;
  LibraryPath := ConcatPaths([AppGlobals.Storage.DataDir, FDownloadPackage]);

  ForceDirectories(FFilesDir);
  if FileExists(LibraryPath) then
  begin
    H := LoadLibrary(PChar(LibraryPath));
    if H > 0 then
    begin
      for i := 0 to FFilenames.Count - 1 do
        try
          Res := TResourceStream.Create(H, StringReplace(FFilenames[i], '.', '_', [rfReplaceAll]), Windows.RT_RCDATA);
          try
            Res.SaveToFile(ConcatPaths([FFilesDir, FFilenames[i]]));
          finally
            Res.Free;
          end;
        except
        end;
      Result := FilesExtracted;
      FreeLibrary(H);
    end else
      SysUtils.DeleteFile(LibraryPath);
  end;
end;

function TAddonBase.FGetDependenciesMet: Boolean;
var
  i: Integer;
  Addon: TAddonBase;
begin
  for i := 0 to FNeededAddons.Count - 1 do
  begin
    Addon := AppGlobals.AddonManager.Find(FNeededAddons[i]);
    if (Addon = nil) or (not Addon.FilesExtracted) then
      Exit(False);
  end;
  Exit(True);
end;

function TAddonBase.FGetFilesExtracted: Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to FFilenames.Count - 1 do
    if not FileExists(ConcatPaths([FFilesDir, FFilenames[i]])) then
    begin
      Result := False;
      Break;
    end;
end;

function TAddonBase.FGetHelp: string;
begin
  Result := '';
end;

function TAddonBase.FGetName: string;
begin
  Result := '';
end;

function TAddonBase.FGetPackageDownloaded: Boolean;
begin
  Result := FileExists(ConcatPaths([AppGlobals.Storage.DataDir, FDownloadPackage]));
end;

function TAddonBase.FGetVersionOkay: Boolean;
var
  Ver: TAppVersion;
begin
  Result := True;
  try
    Ver := TFunctions.GetFileVersion(ConcatPaths([AppGlobals.Storage.DataDir, FDownloadPackage]));
    if TFunctions.IsVersionNewer(Ver, FNeededVersion) then
      Result := False;
  except
    Result := False;
  end;

  if not Result then
    SysUtils.DeleteFile(ConcatPaths([AppGlobals.Storage.DataDir, FDownloadPackage]));
end;

function TAddonBase.ShowInitMessage(Handle: THandle): Boolean;
begin
  Result := True;
end;

end.
