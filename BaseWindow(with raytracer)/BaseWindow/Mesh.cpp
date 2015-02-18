#include "Mesh.h"
using namespace std;

Mesh::Mesh()
{
	m_meshTriangles.clear();
	m_material = Material();
	m_nrOfFaces = 0;
}

Mesh::~Mesh()
{
	m_meshTriangles.clear();
}

void Mesh::init()
{

}

void Mesh::loadObj(char* textFile)
{
	
	vector<XMFLOAT4> positions;
	vector<XMFLOAT4> normals;
	vector<XMFLOAT2> texCoords;

	fstream file( textFile );

	if (!file.is_open())
	{
		MessageBox(NULL, "OBJ file not found!", "Create OBJ FAILED", MB_OK);
		return;
	}

	string srcMaterial;
	string line;
	string prefix;
	int id = 0;
	while( !file.eof() )
	{
		prefix = "NULL";
		stringstream lineStream;

		getline( file, line );
		lineStream << line;
		lineStream >> prefix;
		if(prefix == "mtllib")
		{	
			stringstream ss;
			string s;
			lineStream >> s;
			ss << "Meshi/";
			ss << s;
			ss >> prefix;
			loadMaterial(prefix.c_str());
		}

		if( prefix == "v" )
		{
			XMFLOAT4 pos;
			lineStream >> pos.x >> pos.y >> pos.z;
			pos.z *= -1.f;
			pos.w = 1.0f;
			positions.push_back( pos );
		}
		else if( prefix == "vn" )
		{
			XMFLOAT4 normal;
			lineStream >> normal.x >> normal.y >> normal.z;
			normal.z *= -1.f;
			normal.w = 0.0f;
			normals.push_back( normal );
		}
		else if( prefix == "vt" )
		{
			XMFLOAT2 texC;
			lineStream >> texC.x >> texC.y;
			texC.y = 1 - texC.y;
			texCoords.push_back( texC );
		}
		else if( prefix == "f" )
		{
			m_nrOfFaces++;
			unsigned int iPosition = -1;
			unsigned int iTexCoord = -1;
			unsigned int iNormal = -1;
			TriangleMat vertex;
			char slash;
			if (normals.size() > 0 && texCoords.size() > 0)
			{
				lineStream >> iPosition >> slash >> iTexCoord >> slash >> iNormal;
				vertex.pos0 = positions[iPosition - 1];
				vertex.normal = normals[iNormal - 1];
				vertex.textureCoordinate0 = texCoords[iTexCoord - 1];
				//pos1
				lineStream >> iPosition >> slash >> iTexCoord >> slash >> iNormal;
				vertex.pos1 = positions[iPosition - 1];
				vertex.textureCoordinate1 = texCoords[iTexCoord - 1];
				//pos2
				lineStream >> iPosition >> slash >> iTexCoord >> slash >> iNormal;
				vertex.pos2 = positions[iPosition - 1];
				vertex.textureCoordinate2 = texCoords[iTexCoord - 1];
			}
			else if (normals.size() > 0)
			{
				lineStream >> iPosition >> slash >> iNormal;
				vertex.pos0 = positions[iPosition - 1];
				vertex.normal = normals[iNormal - 1];
				vertex.textureCoordinate0 = XMFLOAT2(0,0);
				//pos1
				lineStream >> iPosition >> slash >> iNormal;
				vertex.pos1 = positions[iPosition - 1];
				vertex.textureCoordinate1 = XMFLOAT2(0, 0);
				//pos2
				lineStream >> iPosition >> slash >> iNormal;
				vertex.pos2 = positions[iPosition - 1];
				vertex.textureCoordinate2 = XMFLOAT2(0, 0);
			}
			else if (texCoords.size() > 0)
			{
				lineStream >> iPosition >> slash >> iTexCoord;
				vertex.pos0 = positions[iPosition - 1];
				vertex.normal = XMFLOAT4(0,0,0,0);
				vertex.textureCoordinate0 = texCoords[iTexCoord - 1];
				//pos1
				lineStream >> iPosition >> slash >> iTexCoord;
				vertex.pos1 = positions[iPosition - 1];
				vertex.textureCoordinate1 = texCoords[iTexCoord - 1];
				//pos2
				lineStream >> iPosition >> slash >> iTexCoord;
				vertex.pos2 = positions[iPosition - 1];
				vertex.textureCoordinate2 = texCoords[iTexCoord - 1];
			}
			else
			{
				lineStream >> iPosition;
				vertex.pos0 = positions[iPosition - 1];
				vertex.normal = XMFLOAT4(0,0,0,0);
				vertex.textureCoordinate0 = XMFLOAT2(0, 0);
				//pos1
				lineStream >> iPosition;
				vertex.pos1 = positions[iPosition - 1];
				vertex.textureCoordinate1 = XMFLOAT2(0, 0);
				//pos2
				lineStream >> iPosition;
				vertex.pos2 = positions[iPosition - 1];
				vertex.textureCoordinate2 = XMFLOAT2(0, 0);
			}
			vertex.ID = id + 20;
			m_meshTriangles.push_back( vertex );
			/*if (m_meshTriangles.size() > 12500)
			{
				return;
			}*/
			id++;
			vertex.pad = 1.0f;
			vertex.color = XMFLOAT4(0.f, 0.f, 0.f, 0.f);
		}
	}
	m_meshTriangles.shrink_to_fit();
	file.close();
	positions.clear();
	normals.clear();
	texCoords.clear();
}

void Mesh::loadMaterial(string filename)
{
	fstream file( filename.c_str() );

	string line;
	string prefix;
	
	while( !file.eof() )
	{
		prefix = "NULL";
		stringstream lineStream;
		
		getline( file, line );
		lineStream << line;
		lineStream >> prefix;

		if(prefix == "Ns")
		{
			lineStream >> m_material.Ns;
		}
		if( prefix == "Ni" )
		{
			lineStream >> m_material.Ni;
		}
		else if( prefix == "d" )
		{
			lineStream >> m_material.d;
		}
		else if( prefix == "Tr" )
		{
			lineStream >> m_material.Tr;
		}
		else if( prefix == "Tf" )
		{
			lineStream >> m_material.Tf.x >> m_material.Tf.y >> m_material.Tf.z;
		}
		else if( prefix == "illum" )
		{
			lineStream >> m_material.illum;
		}
		else if( prefix == "Ka" )
		{
			lineStream >> m_material.Ka.x >> m_material.Ka.y >> m_material.Ka.z;
		}
		else if( prefix == "Kd" )
		{
			lineStream >> m_material.Kd.x >> m_material.Kd.y >> m_material.Kd.z;
		}
		else if( prefix == "Ks" )
		{
			lineStream >> m_material.Ks.x >> m_material.Ks.y >> m_material.Ks.z;
		}
		else if( prefix == "Ke" )
		{
			lineStream >> m_material.Ke.x >> m_material.Ke.y >> m_material.Ke.z;
		}
		else if( prefix == "map_Ka" )
		{
			lineStream >> m_material.map_Ka;
		}
		else if( prefix == "map_Kd" )
		{
			lineStream >> m_material.map_Kd;

			textureName = m_material.map_Kd.c_str();
		}
	}
	file.close();
}

TriangleMat* Mesh::getTriangles()
{
	return m_meshTriangles.data();
}

std::vector<TriangleMat>* Mesh::getTriangleList()
{
	return &m_meshTriangles;
}

Material* Mesh::getMaterial()
{
	return &m_material;
}

int Mesh::getNrOfFaces()
{
	return m_nrOfFaces;
}

std::string Mesh::getTextureString()
{
	return textureName;
}

void Mesh::setColor(XMFLOAT4 _color)
{
	for (int i = 0; i < getNrOfFaces(); i++)
	{
		m_meshTriangles.at(i).color = _color;
	}
}