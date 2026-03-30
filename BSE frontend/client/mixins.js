// layout
export const layout = { display: 'flex' };
export const layoutInline = { display: 'inline-flex' };
export const layoutHorizontal = { ...layout, flexDirection: 'row' };
export const layoutHorizontalReverse = { ...layout, flexDirection: 'row-reverse' };
export const layoutVertical = { ...layout, flexDirection: 'column' };
export const layoutVerticalReverse = { ...layout, flexDirection: 'column-reverse' };
export const layoutWrap = { flexWrap: 'wrap' };
export const layoutWrapReverse = { flexWrap: 'wrap-reverse' };
export const layoutFlex = { flex: 1, flexBasis: 'auto' };
export const layoutFlexAuto = { flex: '1 1 auto' };
export const layoutFlexNone = { flex: 'none' };
export const layoutFlexNoShrink = { flex: '1 0 auto', flexBasis: 'auto' };
export const layoutFlexNoGrow = { flex: '0 1 auto', flexBasis: 'auto' };
// layout align in cross axis
export const layoutStart = { alignItems: 'flex-start' };
export const layoutCenter = { alignItems: 'center' };
export const layoutEnd = { alignItems: 'flex-end' };
export const layoutBaseline = { alignItems: 'baseline' };
export const layoutStretch = { alignItems: 'stretch' };
// layout align in main axis
export const layoutStartJustified = { justifyContent: 'flex-start' };
export const layoutCenterJustified = { justifyContent: 'center' };
export const layoutEndJustified = { justifyContent: 'flex-end' };
export const layoutAroundJustified = { justifyContent: 'space-around' };
export const layoutJustified = { justifyContent: 'space-between' };
export const layoutCenterCenter = { ...layoutCenter, ...layoutCenterJustified };
// layout items self align
export const layoutSelfStart = { alignSelf: 'flex-start' };
export const layoutSelfCenter = { alignSelf: 'center' };
export const layoutSelfEnd = { alignSelf: 'flex-end' };
export const layoutSelfStretch = { alignSelf: 'stretch' };
export const layoutSelfBaseline = { alignSelf: 'baseline' };
// layout multiline align in main axis
export const layoutStartAligned = { alignContent: 'flex-start' };
export const layoutCenterAligned = { alignContent: 'center' };
export const layoutEndAligned = { alignContent: 'flex-end' };
export const layoutBetweenAligned = { alignContent: 'space-between' };
export const layoutAroundAligned = { alignContent: 'space-around' };
// layout other
export const layoutBlock = { display: 'block' };
export const layoutRelative = { position: 'relative' };
export const layoutFullbleed = { margin: 0, height: '100vh' };
export const layoutFit = {
  position: 'absolute', top: 0, right: 0, bottom: 0, left: 0,
};
