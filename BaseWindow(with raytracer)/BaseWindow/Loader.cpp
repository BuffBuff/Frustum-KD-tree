#include "Loader.h"


Loader::Loader(void)
{
}


Loader::~Loader(void)
{
}


void Loader::LoadObject(char file[256],float mx,float mz,float my,float scale,Object* objekt,float invertX = 1,float invertY = 1,float invertZ = 1)
{
	Vertex pData;

	char buffer[256]="";
	bool last = false;
	float pos[3];
	pos[0] = mx;
	pos[1] = my;
	pos[2] = mz;
	objekt->setPos(pos);

	std::fstream ObjFile;
	ObjFile.open(file,std::fstream::in | std::fstream::out | std::fstream::app);

	std::vector<VECTOR3> Position;
	std::vector<VECTOR3> Normal;
	std::vector<VECTOR2> TextureCoord;


	float x,y,z;
	float u,v;
	int FaceIndex=NULL;
	int Vertexsize=NULL;


	//for(int k = 0 ;k < 90000 ;k++)
	while(!ObjFile.eof())
	{
		pData.normal = VECTOR3(0, 0, 0);
		pData.pos = VECTOR3(0, 0, 0);
		pData.texC = VECTOR2(0, 0);

		ObjFile >> buffer;

		if(0==strcmp(buffer,"v"))
		{
			last = false;
			ObjFile >>x>>y>>z;
			
			Position.push_back(VECTOR3((x*(scale / 10)*invertX), (y*(scale / 10)*invertY), (-z*(scale / 10)*invertZ)));
			
		}
		else if(0==strcmp(buffer,"vt"))
		{
			last = false;
			ObjFile >>u>>v;

			TextureCoord.push_back(VECTOR2(u, 1 - v));
		}
		else if(0==strcmp(buffer,"vn"))
		{
			last = false;
			ObjFile >>x>>y>>z;

			Normal.push_back(VECTOR3(x, y, z));
		}

		else if(0==strcmp(buffer,"f"))
		{
			last = true;

			for(int i = 0; i < 3;i ++ )
			{
				ObjFile >>FaceIndex;
				if(FaceIndex < 0)
					FaceIndex*=-1;
				pData.pos = Position.at(FaceIndex-1);

				if('/'==ObjFile.peek())         /////  '/'  Ignorieren
				{
					ObjFile.ignore();
					if('/'!=ObjFile.peek()) 
					{

						ObjFile >>FaceIndex;
						if(FaceIndex < 0)
							FaceIndex*=-1;
						pData.texC = TextureCoord.at(FaceIndex-1);
					}
				}
				if('/'==ObjFile.peek())
				{
					ObjFile.ignore();

					if('/'!=ObjFile.peek()) 
					{
						ObjFile >>FaceIndex;
						if(FaceIndex < 0)
							FaceIndex*=-1;
						pData.normal = Normal.at(FaceIndex-1);
					}

				}
				//Data->push_back(pData);
				objekt->addData(pData);
			}
		}
		else if(0==strcmp(buffer,"s"))
		{
			last = false;
		}
		else if(0==strcmp(buffer,"g"))
		{
			last = false;
		}
		else if(0==strcmp(buffer,"#"))
		{
			last = false;
		}
		else if(buffer[0] == '#')
		{
			last = false;
		}
		else if(0==strcmp(buffer,"usemtl"))
		{
			last = false;
		}
		else if(last == true && !ObjFile.eof())
		{

			objekt->lastFace();
			//Data->push_back(Data->at(Data->size()-3));
			//objekt->addData(Data->at(Data->size()-2));
			//Data->push_back(Data->at(Data->size()-2));

			char temp[256] = "";
			int i = 0;
			int j = 0;

			while(buffer[i] != '/' && buffer[i] != 0)
			{
				temp[j] = buffer[i];
				i++;
				j++;
			}
			i++;
			j = 0;
			FaceIndex = atof(temp);
			if(FaceIndex < 0)
				FaceIndex*=-1;
			pData.pos = Position.at(FaceIndex-1);

			if(buffer[i-1] != 0)
			{

				for(int l = 0;l < 256;l++)
				{
					temp[l] = NULL;
				}


				while(buffer[i] != '/' && buffer[i] != 0)
				{
					temp[j] = buffer[i];
					i++;
					j++;
				}
				i++;
				j = 0;
				FaceIndex = atof(temp);
				if(FaceIndex < 0)
					FaceIndex*=-1;
				pData.texC = TextureCoord.at(FaceIndex-1);

				if(buffer[i-1] != 0)
				{

					for(int l = 0;l < 256;l++)
					{
						temp[l] = NULL;
					}

					while(buffer[i] != 0)
					{
						temp[j] = buffer[i];
						i++;
						j++;
					}
					FaceIndex = atof(temp);
					if(FaceIndex < 0)
						FaceIndex*=-1;
					pData.normal = Normal.at(FaceIndex-1);

				}

			}
			//Data->push_back(pData);
			objekt->addData(pData);
		}     
	}


	ObjFile.close();

}

