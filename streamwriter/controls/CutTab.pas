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
unit CutTab;

interface

uses
  Windows, SysUtils, Classes, Controls, StdCtrls, ExtCtrls, ComCtrls, Buttons,
  MControls, LanguageObjects, Tabs, CutView, Functions, AppData, SharedControls,
  DynBass, Logging, CutTabSearchSilence;

type
  TCutToolBar = class(TToolBar)
  private
    FSep: TToolButton;
    FZoomIn: TToolButton;
    FZoomOut: TToolButton;
    FPosEdit: TToolButton;
    FPosPlay: TToolButton;
    FAutoCut: TToolButton;
    FCut: TToolButton;
    FUndo: TToolButton;
    FPosEffectsMarker: TToolButton;
    FApplyFadein: TToolButton;
    FApplyFadeout: TToolButton;
    FApplyEffects: TToolButton;
    FPlay: TToolButton;
    FStop: TToolButton;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Setup;
  end;

  TFileSavedEvent = procedure(Sender: TObject; Filesize, Length: UInt64) of object;

  TCutTab = class(TMainTabSheet)
  private
    FToolbarPanel: TPanel;
    FToolBar: TCutToolBar;
    FVolume: TVolumePanel;
    FCutView: TCutView;
    FFilename: string;

    FOnSaved: TFileSavedEvent;
    FOnVolumeChanged: TSeekChangeEvent;
    FOnPlayStarted: TNotifyEvent;

    procedure UpdateButtons;

    procedure PosClick(Sender: TObject);
    procedure AutoCutClick(Sender: TObject);
    procedure CutClick(Sender: TObject);
    procedure UndoClick(Sender: TObject);
    procedure PlayClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure ApplyFadeinClick(Sender: TObject);
    procedure ApplyFadeoutClick(Sender: TObject);
    procedure ApplyEffectsClick(Sender: TObject);
    procedure ZoomInClick(Sender: TObject);
    procedure ZoomOutClick(Sender: TObject);

    procedure CutViewStateChanged(Sender: TObject);
    procedure VolumeTrackbarChange(Sender: TObject);

    procedure FSetVolume(Value: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Setup(Filename: string; ToolBarImages: TImageList);
    procedure PausePlay;

    property Filename: string read FFilename;
    property Volume: Integer write FSetVolume;

    property CutView: TCutView read FCutView;
    property OnSaved: TFileSavedEvent read FOnSaved write FOnSaved;
    property OnVolumeChanged: TSeekChangeEvent read FOnVolumeChanged write FOnVolumeChanged;
    property OnPlayStarted: TNotifyEvent read FOnPlayStarted write FOnPlayStarted;
  end;

implementation

{ TCutTab }

constructor TCutTab.Create(AOwner: TComponent);
begin
  inherited;

  ImageIndex := 17;
  ShowCloseButton := True;
end;

procedure TCutTab.UpdateButtons;
begin
  FToolBar.FPosEdit.Enabled := FCutView.CanSetLine;
  FToolBar.FPosPlay.Enabled := FCutView.CanSetLine;
  FToolBar.FAutoCut.Enabled := FCutView.CanAutoCut;
  FToolBar.FPosPlay.Enabled := FCutView.CanSetLine;
  FToolBar.FCut.Enabled := FCutView.CanCut;
  FToolBar.FZoomIn.Enabled := FCutView.CanZoomIn;
  FToolBar.FZoomOut.Enabled := FCutView.CanZoomOut;
  FToolBar.FPosEffectsMarker.Enabled := FCutView.CanEffectsMarker;
  FToolBar.FUndo.Enabled := FCutView.CanUndo;
  FToolBar.FApplyFadein.Enabled := FCutView.CanApplyFadeIn;
  FToolBar.FApplyFadeout.Enabled := FCutView.CanApplyFadeOut;
  FToolBar.FApplyEffects.Enabled := FCutView.CanApplyEffects;
  FToolBar.FPlay.Enabled := FCutView.CanPlay and Bass.DeviceAvailable;
  FToolBar.FStop.Enabled := FCutView.CanStop and Bass.DeviceAvailable;

  // Das muss so, sonst klappt das .Down := True nicht, wenn sie
  // vorher Disabled waren, vor dem Enable da oben...
  FToolBar.FPosEdit.Down := False;
  FToolBar.FPosPlay.Down := False;
  FToolBar.FPosEffectsMarker.Down := False;

  case FCutView.LineMode of
    lmEdit:
      FToolBar.FPosEdit.Down := True;
    lmPlay:
      FToolBar.FPosPlay.Down := True;
    lmEffectsMarker:
      FToolBar.FPosEffectsMarker.Down := True;
  end;
end;

procedure TCutTab.VolumeTrackbarChange(Sender: TObject);
begin
  if FCutView.Player <> nil then
    FCutView.Player.Volume := FVolume.Volume;

  if Assigned(FOnVolumeChanged) then
    FOnVolumeChanged(Self, FVolume.Volume);
end;

procedure TCutTab.ZoomInClick(Sender: TObject);
begin
  FCutView.ZoomIn;
end;

procedure TCutTab.ZoomOutClick(Sender: TObject);
begin
  FCutView.ZoomOut;
end;

procedure TCutTab.PosClick(Sender: TObject);
begin
  if TToolButton(Sender).Down then
    Exit;

  FToolBar.FPosEdit.Down := False;
  FToolBar.FPosPlay.Down := False;
  FToolBar.FPosEffectsMarker.Down := False;

  if Sender = FToolBar.FPosEdit then
  begin
    FCutView.LineMode := lmEdit;
    FToolBar.FPosEdit.Down := True;
  end;
  if Sender = FToolBar.FPosPlay then
  begin
    FCutView.LineMode := lmPlay;
    FToolBar.FPosPlay.Down := True;
  end;
  if Sender = FToolBar.FPosEffectsMarker then
  begin
    FCutView.LineMode := lmEffectsMarker;
    FToolBar.FPosEffectsMarker.Down := True;
  end;
end;

procedure TCutTab.ApplyFadeinClick(Sender: TObject);
begin
  FCutView.ApplyFadein;
end;

procedure TCutTab.ApplyFadeoutClick(Sender: TObject);
begin
  FCutView.ApplyFadeout;
end;

procedure TCutTab.ApplyEffectsClick(Sender: TObject);
begin
  FCutView.ApplyEffects;
end;

procedure TCutTab.AutoCutClick(Sender: TObject);
var
  F: TfrmCutTabSearchSilence;
begin
  F := TfrmCutTabSearchSilence.Create(Self);
  try
    F.ShowModal;

    if F.Okay then
    begin
      FCutView.AutoCut(F.SilenceLevel, F.SilenceLength);
    end;
  finally
    F.Free;
  end;
end;

procedure TCutTab.CutClick(Sender: TObject);
begin
  FCutView.Cut;
end;

procedure TCutTab.UndoClick(Sender: TObject);
begin
  FCutView.Undo;
end;

procedure TCutTab.PausePlay;
begin
  FCutView.Stop;
end;

procedure TCutTab.PlayClick(Sender: TObject);
begin
  FCutView.Play;

  if Assigned(FOnPlayStarted) then
    FOnPlayStarted(Self);
end;

procedure TCutTab.StopClick(Sender: TObject);
begin
  FCutView.Stop;
end;

procedure TCutTab.CutViewStateChanged(Sender: TObject);
begin
  UpdateButtons;
end;

destructor TCutTab.Destroy;
begin

  inherited;
end;

procedure TCutTab.FSetVolume(Value: Integer);
begin
  FVolume.NotifyOnMove := False;
  FVolume.Volume := Value;
  if FCutView.Player <> nil then
    FCutView.Player.Volume := Value;
  FVolume.NotifyOnMove := True;
end;

procedure TCutTab.Setup(Filename: string; ToolBarImages: TImageList);
begin
  MaxWidth := 120;
  Caption := ExtractFileName(StringReplace(Filename, '&', '&&', [rfReplaceAll]));
  FFilename := Filename;

  FToolbarPanel := TPanel.Create(Self);
  FToolbarPanel.Align := alTop;
  FToolbarPanel.BevelOuter := bvNone;
  FToolbarPanel.Parent := Self;
  FToolbarPanel.ClientHeight := 24;

  FToolBar := TCutToolBar.Create(Self);
  FToolBar.Parent := FToolbarPanel;
  FToolBar.Images := ToolBarImages;
  FToolBar.Align := alLeft;
  FToolBar.Width := Self.ClientWidth - 130;
  FToolBar.Height := 24;
  FToolBar.Indent := 2;
  FToolBar.Setup;

  FToolBar.FPosEdit.OnClick := PosClick;
  FToolBar.FPosPlay.OnClick := PosClick;
  FToolBar.FZoomIn.OnClick := ZoomInClick;
  FToolBar.FZoomOut.OnClick := ZoomOutClick;
  FToolBar.FPosEffectsMarker.OnClick := PosClick;
  FToolBar.FAutoCut.OnClick := AutoCutClick;
  FToolBar.FCut.OnClick := CutClick;
  FToolBar.FUndo.OnClick := UndoClick;
  FToolBar.FApplyFadein.OnClick := ApplyFadeinClick;
  FToolBar.FApplyFadeout.OnClick := ApplyFadeoutClick;
  FToolBar.FApplyEffects.OnClick := ApplyEffectsClick;
  FToolBar.FPlay.OnClick := PlayClick;
  FToolBar.FStop.OnClick := StopClick;

  FVolume := TVolumePanel.Create(Self);
  FVolume.Parent := FToolbarPanel;
  FVolume.Align := alRight;
  FVolume.Setup;
  FVolume.Width := 140;
  FVolume.Volume := AppGlobals.PlayerVolume;
  FVolume.OnVolumeChange := VolumeTrackbarChange;

  FCutView := TCutView.Create(Self);
  FCutView.Parent := Self;
  FCutView.Padding.Top := 2;
  FCutView.Align := alClient;
  FCutView.OnStateChanged := CutViewStateChanged;

  UpdateButtons;
  Language.Translate(Self);
  FCutView.LoadFile(Filename);
end;

{ TCutToolbar }

constructor TCutToolBar.Create(AOwner: TComponent);
begin
  inherited;

  ShowHint := True;
  Transparent := True;
end;

procedure TCutToolBar.Setup;
begin
  FStop := TToolButton.Create(Self);
  FStop.Parent := Self;
  FStop.Hint := 'Stop';
  FStop.ImageIndex := 1;

  FPlay := TToolButton.Create(Self);
  FPlay.Parent := Self;
  FPlay.Hint := 'Play';
  FPlay.ImageIndex := 33;

  FPosPlay := TToolButton.Create(Self);
  FPosPlay.Parent := Self;
  FPosPlay.Hint := 'Set playposition';
  FPosPlay.ImageIndex := 27;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FAutoCut := TToolButton.Create(Self);
  FAutoCut.Parent := Self;
  FAutoCut.Hint := 'Show silence...';
  FAutoCut.ImageIndex := 19;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FUndo := TToolButton.Create(Self);
  FUndo.Parent := Self;
  FUndo.Hint := 'Undo';
  FUndo.ImageIndex := 18;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FApplyEffects := TToolButton.Create(Self);
  FApplyEffects.Parent := Self;
  FApplyEffects.Hint := 'Apply effects...';
  FApplyEffects.ImageIndex := 56;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FCut := TToolButton.Create(Self);
  FCut.Parent := Self;
  FCut.Hint := 'Cut';
  FCut.ImageIndex := 17;

  FPosEdit := TToolButton.Create(Self);
  FPosEdit.Parent := Self;
  FPosEdit.Hint := 'Set cutpositions (left mousebutton sets start, right button sets end)';
  FPosEdit.ImageIndex := 37;

  FSep := TToolButton.Create(Self);
  FSep.Parent := Self;
  FSep.Style := tbsSeparator;
  FSep.Width := 8;

  FApplyFadeout := TToolButton.Create(Self);
  FApplyFadeout.Parent := Self;
  FApplyFadeout.Hint := 'Apply fadeout';
  FApplyFadeout.ImageIndex := 55;

  FApplyFadein := TToolButton.Create(Self);
  FApplyFadein.Parent := Self;
  FApplyFadein.Hint := 'Apply fadein';
  FApplyFadein.ImageIndex := 54;

  FZoomOut := TToolButton.Create(Self);
  FZoomOut.Parent := Self;
  FZoomOut.Hint := 'Zoom out';
  FZoomOut.ImageIndex := 66;

  FZoomIn := TToolButton.Create(Self);
  FZoomIn.Parent := Self;
  FZoomIn.Hint := 'Zoom in';
  FZoomIn.ImageIndex := 48;

  FPosEffectsMarker := TToolButton.Create(Self);
  FPosEffectsMarker.Parent := Self;
  FPosEffectsMarker.Hint := 'Select area';
  FPosEffectsMarker.ImageIndex := 53;
end;

end.

