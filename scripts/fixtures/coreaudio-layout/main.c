static AudioChannelLayout *reset_layout(void) {
 AudioChannelLayout *l=(void*)raw_data;memset(raw_data,0,sizeof(raw_data));
 raw_size=offsetof(AudioChannelLayout,mChannelDescriptions)+8*sizeof(AudioChannelDescription);actual_channels=8;
 l->mChannelLayoutTag=kAudioChannelLayoutTag_UseChannelDescriptions;l->mNumberChannelDescriptions=8;
 unsigned labels[]={1,2,3,4,5,6,49,51};for(unsigned i=0;i<8;i++)l->mChannelDescriptions[i].mChannelLabel=labels[i];return l;
}
int main(void) {
 struct spatial_output_layout out, before;struct coreaudio_stream stream;UInt32 size;AudioChannelLayout *l=reset_layout();
 assert(get_spatial_output_layout("mock",&out,&size)==S_OK);assert(out.layout.mNumberChannelDescriptions==8);
 assert(out.layout.mChannelDescriptions[6].mChannelLabel==49 && out.layout.mChannelDescriptions[7].mChannelLabel==51);
 assert(configure_native_spatial_dry_output(&stream,&out.layout)==S_OK);assert(stream.spatial_dry_output[0]==0&&stream.spatial_dry_output[1]==1);
 l->mChannelDescriptions[0].mChannelLabel=49;l->mChannelDescriptions[6].mChannelLabel=1;
 assert(get_spatial_output_layout("mock",&out,&size)==S_OK);assert(configure_native_spatial_dry_output(&stream,&out.layout)==S_OK);assert(stream.spatial_dry_output[0]==6&&stream.spatial_dry_output[1]==1);
 before=out;l->mChannelDescriptions[6].mChannelFlags=kAudioChannelFlags_SphericalCoordinates;l->mChannelDescriptions[6].mCoordinates[1]=45;
 assert(get_spatial_output_layout("mock",&out,&size)==S_OK);assert(memcmp(&before,&out,size));assert(out.layout.mChannelDescriptions[6].mCoordinates[1]==45);
 l=reset_layout();l->mChannelDescriptions[6].mChannelLabel=kAudioChannelLabel_UseCoordinates;l->mChannelDescriptions[6].mChannelFlags=kAudioChannelFlags_SphericalCoordinates;l->mChannelDescriptions[6].mCoordinates[1]=45;
 assert(get_spatial_output_layout("mock",&out,&size)==S_OK);
 l->mChannelDescriptions[6].mCoordinates[1]=NAN;assert(FAILED(get_spatial_output_layout("mock",&out,&size)));
 l=reset_layout();actual_channels=7;assert(FAILED(get_spatial_output_layout("mock",&out,&size)));
 l=reset_layout();raw_size--;assert(FAILED(get_spatial_output_layout("mock",&out,&size)));
 l=reset_layout();l->mNumberChannelDescriptions=65;assert(FAILED(get_spatial_output_layout("mock",&out,&size)));
 l=reset_layout();l->mChannelDescriptions[6].mChannelLabel=kAudioChannelLabel_Discrete_0;assert(FAILED(get_spatial_output_layout("mock",&out,&size)));
 l=reset_layout();l->mChannelDescriptions[6].mChannelLabel=kAudioChannelLabel_Unknown;assert(FAILED(get_spatial_output_layout("mock",&out,&size)));
 l=reset_layout();l->mChannelLayoutTag=kAudioChannelLayoutTag_MPEG_5_1_A;actual_channels=6;assert(get_spatial_output_layout("mock",&out,&size)==S_OK);assert(out.layout.mNumberChannelDescriptions==6);
 l=reset_layout();l->mChannelLayoutTag=kAudioChannelLayoutTag_UseChannelBitmap;l->mChannelBitmap=3;actual_channels=2;assert(get_spatial_output_layout("mock",&out,&size)==S_OK);
 l=reset_layout();for(unsigned i=0;i<8;i++)l->mChannelDescriptions[i].mChannelLabel=kAudioChannelLabel_Unknown;
 actual_channels=2;fallback_allowed=TRUE;assert(get_spatial_output_layout("mock",&out,&size)==S_OK);assert(out.layout.mNumberChannelDescriptions==2);
 actual_channels=8;assert(FAILED(get_spatial_output_layout("mock",&out,&size)));fallback_allowed=FALSE;
 puts("Native layout scenarios passed: 5.1.2, reordered dry channels, coordinates/change identity, malformed/count mismatch, unknown/discrete, tag and bitmap expansion.");return 0;
}
