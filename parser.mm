#import <Foundation/Foundation.h>
#import <vector>
#import <string>

const bool DEBUG = false;

const unsigned char MASK_08 = (1<<8)-1;
const unsigned char MASK_07 = (1<<7)-1;
const unsigned char MASK_06 = (1<<6)-1;
const unsigned char MASK_05 = (1<<5)-1;
const unsigned char MASK_04 = (1<<4)-1;
const unsigned char MASK_03 = (1<<3)-1;
const unsigned char MASK_02 = (1<<2)-1;
const unsigned char MASK_01 = 1;

unsigned int toU32(unsigned char *p) { return *((unsigned int *)p); }
unsigned int swapU32(unsigned int n) { return ((n>>24)&0xFF)|(((n>>16)&0xFF)<<8)|(((n>>8)&0xFF)<<16)|((n&0xFF)<<24); }
unsigned int U32(unsigned char *p) { return swapU32(toU32(p)); }

unsigned short toU16(uint8 *p) { return *((uint16 *)p);  }
unsigned short swapU16(unsigned short n) { return ((n>>8)&0xFF)|((n&0xFF)<<8); }
unsigned short U16(unsigned char *p) { return swapU16(toU16(p)); }

unsigned char U8(unsigned char *p) { return *p; }

typedef struct _buffer {
	unsigned char bytes[64];
	unsigned long length = 64;
	unsigned long pos = 0;
	unsigned char bit = 8;
} buffer_t;

unsigned char read_bit(buffer_t *buf) {
	if(buf->bit==0) {
		buf->pos++;
		buf->bit = 8;
	}
	if(buf->pos>=buf->length) {
		NSLog(@"buffer overrun");
	}
	unsigned char ret = buf->bytes[buf->pos]&(1<<(buf->bit-1));
	buf->bit--;
	return ret>0?1:0;
}

unsigned int read_bits(buffer_t *buf, int nbits) {
	unsigned int ret = 0;
	for(unsigned char i=0; i<nbits; i++) {
		ret = (ret<<1)|read_bit(buf);
	}
	return ret;
}

unsigned int read_uev(buffer_t *buf) { // read exp-golomb code
	std::string golomb = "";
	int zero_leading_bits = -1;
	for(int b=0; !b; zero_leading_bits++) {
		b = read_bit(buf);
		golomb+=std::to_string(b);
	}
	unsigned int ret = ((1<<zero_leading_bits)-1)+read_bits(buf, zero_leading_bits);	
	unsigned int len = golomb.length()-1;
	while(len--) {
		golomb+=std::to_string((ret>>len)&1);
	}
	if(DEBUG) NSLog(@"[%s]",golomb.c_str());
	return ret;
}

int main(int argc, char *argv[]) {
	@autoreleasepool {
		
		NSData *data = [NSData dataWithContentsOfFile:@"/Users/mizt/Downloads/20250425T113604962+0900.mov"]; 
		if(data) {
			
			const int length = data.length;
			unsigned char *u8 = (unsigned char *)data.bytes;

			int seek = -1;
			
			for(int n=0; n<length-3; n++) {
				if(*((unsigned int *)(u8+n))==0x43637668) {
					seek = n;
					break;
				}
			}
			
			if(seek>=0) {
				
				unsigned char *hvcC = u8+seek+4;
				hvcC++; // 1
				
				if(DEBUG) {
					NSLog(@"setU8(0x%X);",*hvcC);
				}
				hvcC++;
				
				unsigned int u32 = *((unsigned int *)hvcC);
				std::string s = "0b";
				for(int n=0; n<32; n++) s+=((u32>>n)&1)?"1":"0";
				if(DEBUG) {
					NSLog(@"setU32(%s);",s.c_str());
				}
				hvcC+=4;
				
				unsigned char u8 = *((unsigned char *)hvcC);
				s = "0b";
				for(int n=0; n<8; n++) s+=((u8>>n)&1)?"1":"0";
				if(DEBUG) {
					NSLog(@"setU8(%s);",s.c_str());
				}
				hvcC++;
				
				u8 = *((unsigned char *)hvcC);
				s = "0b";
				for(int n=0; n<8; n++) s+=((u8>>n)&1)?"1":"0";
				if(DEBUG) {
					NSLog(@"setU8(%s);",s.c_str());
				}
				hvcC++;
				
				if(DEBUG) {
					NSLog(@"setU32(0x%X);",*((unsigned int *)hvcC));
				}
				hvcC+=4;
				if(DEBUG) {
					NSLog(@"setU8((unsigned char)(%0.1f*30));",(*hvcC)/30.f);
				}
				hvcC++;
				
				if(DEBUG) {
					U16(hvcC);
				}
				hvcC+=2;
				
				if(DEBUG) {
					NSLog(@"setU8(0x%X);",*hvcC);
				}
				hvcC++;
				
				if(DEBUG) {
					NSLog(@"setU8(0x%X);",*hvcC);
				}
				hvcC++;
				
				if(DEBUG) {
					NSLog(@"setU8(0x%X);",*hvcC);
				}
				hvcC++;
				
				if(DEBUG) {
					NSLog(@"setU8(0x%X);",*hvcC);
				}
				hvcC++;
				
				if(DEBUG) {
					NSLog(@"setU16(0x%X);",*((unsigned short *)hvcC));
				}
				hvcC+=2;
				
				if(DEBUG) {
					NSLog(@"setU8(0x%X);",*hvcC);
				}
				hvcC++;
				
				if(DEBUG) {
					NSLog(@"%d",*hvcC);
				}
				hvcC++;
				
				// VPS
				hvcC++;
				hvcC+=2;
				unsigned int size = swapU16(*((unsigned short *)hvcC));
				hvcC+=2;
				hvcC+=size;
				
				// SPS
				if(DEBUG) {
					NSLog(@"%d",(*hvcC++)&(~(1<<7))); // 33
				}
				hvcC++;
				
				if(DEBUG) {
					NSLog(@"%d",swapU16(*((unsigned short *)hvcC)));
				}
				hvcC+=2;
				
				size = swapU16(*((unsigned short *)hvcC));
				if(DEBUG) {
					NSLog(@"%d",size);
				}
				hvcC+=2;
				
				unsigned char *sps = new unsigned char[size+4];
				sps[0] = 0;
				sps[1] = 0;
				memcpy(sps+2,hvcC-2,size+2);
				
				if(sps) {
					
					unsigned long length = size+4;
					
					std::vector<unsigned char> bin;
					long len = length-1;
					while(len>=4) {
						
						// Trim Emulation Prevention Byte (EPB)
						
						// 0x00000300 to 0x000000
						// 0x00000301 to 0x000001
						// 0x00000302 to 0x000002
						// 0x00000303 to 0x000003 ?
						
						//if((sps[len]==0||sps[len]==1||sps[len]==2)&&(sps[len-3]==0x00&&sps[len-2]==0x00&&sps[len-1]==0x03)) {
						if((sps[len]==0||sps[len]==1||sps[len]==2||sps[len]==3)&&(sps[len-3]==0x00&&sps[len-2]==0x00&&sps[len-1]==0x03)) {
							bin.insert(bin.begin(),sps[len]);
							len-=2;
						}
						else {
							bin.insert(bin.begin(),sps[len]);
							len--;
						}
						
						bin.insert(bin.begin(),sps[len]);
						len--;
					}
					
					unsigned char *bytes = (unsigned char *)bin.data();
					
					if(DEBUG) {
						NSLog(@"nal_unit_type = %u",(U16(bytes)>>9)&MASK_06);
						NSLog(@"nuh_layer_id = %u",(U16(bytes)>>3)&MASK_06);
						NSLog(@"nuh_temporary_id_plus1 = %u",(U16(bytes))&MASK_03);
					}
					bytes+=2;
					
					if(DEBUG) {
						NSLog(@"sps_video_parameter_set_id = %u",(U8(bytes)>>4)&MASK_04);
						NSLog(@"sps_max_sub_layers_minus1 = %u",(U8(bytes)>>1)&MASK_03);
						NSLog(@"sps_temporal_id_nesting_flag = %u",U8(bytes)&MASK_01);
					}
					bytes++;
					
					if(DEBUG) {
						NSLog(@"profile_tier_level");
						NSLog(@"general_profile_space = %u",(U8(bytes)>>6)&MASK_02);
						NSLog(@"general_tier_flag = %u",(U8(bytes)>>5)&MASK_01);
						NSLog(@"general_profile_idc = %u",U8(bytes)&MASK_05);
					}
					bytes++;
					
					len = 32;
					std::string flags = "0b";
					unsigned int general_profile_compatibility_flags = U32(bytes);
					while(len--) {
						flags+=((general_profile_compatibility_flags>>len)&1)?"1":"0";
					}
					if(DEBUG) {
						NSLog(@"general_profile_compatibility_flags = 0x%08x (%s)",general_profile_compatibility_flags,flags.c_str());
					}
					bytes+=4;
					
					if(DEBUG) {
						NSLog(@"general_progressive_source_flag = %u",(U8(bytes)>>7)&1);
						NSLog(@"general_interlaced_source_flag = %u",(U8(bytes)>>6)&1);
						NSLog(@"general_non_packed_constraint_flag = %u",(U8(bytes)>>5)&MASK_01);
						NSLog(@"general_frame_only_constraint_flag = %u",(U8(bytes)>>4)&MASK_01);
					}
					bytes+=5;
					
					if(DEBUG) {
						NSLog(@"general_inbld_flag = %u",U8(bytes)&MASK_01);
					}
					bytes++;
					
					if(DEBUG) {
						NSLog(@"general_level_idc = %f",U8(bytes)/30.f);
					}
					bytes++;
					
					buffer_t buffer;
					buffer.length = (length-22); 
					for(int n=0; n<buffer.length; n++) {
						buffer.bytes[n] = *bytes++;
					}
					
					if(DEBUG) {
						NSLog(@"sps_seq_parameter_set_id = %d",read_uev(&buffer));
					}
					else {
						read_uev(&buffer);
					}
					
					unsigned char chroma_format_idc = read_uev(&buffer);
					if(chroma_format_idc==3) {
						read_bit(&buffer);
					}
					
					NSLog(@"chroma_format_idc = %d",chroma_format_idc);
										
					NSLog(@"pic_width_in_luma_samples = %d",read_uev(&buffer));
					NSLog(@"pic_height_in_luma_samples = %d",read_uev(&buffer));
					
					if(read_bit(&buffer)) {
						read_uev(&buffer);
						read_uev(&buffer);
						read_uev(&buffer);
						read_uev(&buffer);
					}
					
					NSLog(@"bit_depth_luma = %d",read_uev(&buffer)+8);
					
					if(DEBUG) {
						NSLog(@"bit_depth_chroma = %d",read_uev(&buffer)+8);
					}
					else {
						read_uev(&buffer);
					}
					
					delete[] sps;
				}
			}
		}
	}
}