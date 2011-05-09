#include <iostream>
#include <fstream>

#include <xercesc/util/PlatformUtils.hpp>
#include <xercesc/util/BinFileInputStream.hpp>
#include <xercesc/internal/BinFileOutputStream.hpp>
#include <xercesc/util/PlatformUtils.hpp>
#include <xercesc/sax2/SAX2XMLReader.hpp>
#include <xercesc/sax2/XMLReaderFactory.hpp>
#include <xercesc/framework/XMLGrammarPoolImpl.hpp>
#include <xercesc/sax2/Attributes.hpp>
#include <xercesc/sax2/DefaultHandler.hpp>

using namespace std;
using namespace xercesc;

// Validate an XML file and cache any grammars encountered.
// Returns 0 if no errors are encountered; 1 if there are errors.
// Based on ValidateCache and XSerializerTest from Xerces-C 3.1.1
//
// aelkiss@umich.edu 2011-03-17
// ---------------------------------------------------------------------------
//  This is a simple class that lets us do easy (though not terribly efficient)
//  trancoding of XMLCh data to local code page for display.
// ---------------------------------------------------------------------------
class StrX
{
    public :
        // -----------------------------------------------------------------------
        //  Constructors and Destructor
        // -----------------------------------------------------------------------
        StrX(const XMLCh* const toTranscode)
        {
            // Call the private transcoding method
            fLocalForm = XMLString::transcode(toTranscode); 
        }                              

        ~StrX()
        {
            XMLString::release(&fLocalForm);
        }

        // -----------------------------------------------------------------------
        //  Getter methods
        // -----------------------------------------------------------------------
        const char* localForm() const
        {
            return fLocalForm;
        }

    private :
        // -----------------------------------------------------------------------
        //  Private data members
        //
        //  fLocalForm
        //      This is the local code page form of the string.
        // -----------------------------------------------------------------------
        char*   fLocalForm;
};

inline ostream& operator<<(ostream& target, const StrX& toDump)
{
    target << toDump.localForm();
    return target;
}



class ValidateCacheHandlers : public DefaultHandler
{
    public:
        ValidateCacheHandlers() : fSawErrors(false)
        {
        }

        ~ValidateCacheHandlers()
        {
        }

        void warning(const SAXParseException& e) {
            cerr << "\nWarning at file " << StrX(e.getSystemId())
                << ", line " << e.getLineNumber()
                << ", char " << e.getColumnNumber()
                << "\n  Message: " << StrX(e.getMessage()) << endl;
        }
        void error(const SAXParseException& e) {
            fSawErrors = true;
            cerr << "\nError at file " << StrX(e.getSystemId())
                << ", line " << e.getLineNumber()
                << ", char " << e.getColumnNumber()
                << "\n  Message: " << StrX(e.getMessage()) << endl;
        }
        void fatalError(const SAXParseException& e) {
            fSawErrors = true;
            cerr << "\nFatal error at file " << StrX(e.getSystemId())
                << ", line " << e.getLineNumber()
                << ", char " << e.getColumnNumber()
                << "\n  Message: " << StrX(e.getMessage()) << endl;
        }
        void resetErrors() {
            fSawErrors= false;
        }

        bool getSawError() const { return fSawErrors; }

    private:
        bool fSawErrors;

};

int main(int argc, char** argv) {
    bool errorOccurred = false;
    if(argc != 3) {
        cout << "Usage: validateCache schema.cache file.xml" << endl;
        exit(255);
    }

    XMLPlatformUtils::Initialize();

    BinInputStream* grammarIn = new BinFileInputStream(argv[1]);
    Janitor<BinInputStream> janIn(grammarIn);

    XMLGrammarPool* grammarPool = new XMLGrammarPoolImpl(XMLPlatformUtils::fgMemoryManager);

    try {
        grammarPool->deserializeGrammars(grammarIn);
    } 
    catch (const XSerializationException& e) {
        cerr << "Error reading cached grammar (nonfatal): " << StrX(e.getMessage()) << endl;
    }
    catch (const XMLPlatformUtilsException& e) {
        cerr << "Error reading cached grammar (nonfatal): " << StrX(e.getMessage()) << endl;
    }

    SAX2XMLReader* parser = XMLReaderFactory::createXMLReader(XMLPlatformUtils::fgMemoryManager, grammarPool);
    parser->setFeature(XMLUni::fgXercesCacheGrammarFromParse, true);
    parser->setFeature(XMLUni::fgSAX2CoreNameSpaces, true);
    parser->setFeature(XMLUni::fgXercesSchema, true);
    parser->setFeature(XMLUni::fgXercesHandleMultipleImports, true);
    parser->setFeature(XMLUni::fgXercesSchemaFullChecking, false);
    parser->setFeature(XMLUni::fgSAX2CoreNameSpacePrefixes, true);
    parser->setFeature(XMLUni::fgSAX2CoreValidation, true);
    parser->setFeature(XMLUni::fgXercesDynamic, true);

    ValidateCacheHandlers handler;
    parser->setErrorHandler(&handler);
    parser->setContentHandler(&handler);

    try {
        parser->parse(argv[2]);
    } catch (const XMLException& e) {
        errorOccurred = true;
        cout << StrX(e.getMessage()) << endl;
    }

    if(!handler.getSawError() && !errorOccurred) {
        cout << argv[2] << " OK" << endl;
    } else {
        errorOccurred = true;
    }

    BinOutputStream* grammarOut = new BinFileOutputStream(argv[1]);
    Janitor<BinOutputStream> janOut(grammarOut);

    try {
        grammarPool->serializeGrammars(grammarOut);
    }
    catch (const XSerializationException& e) {
        cerr << "Error saving cached grammar (nonfatal): " << StrX(e.getMessage()) << endl;
    }
    catch (const XMLPlatformUtilsException& e) {
        cerr << "Error saving cached grammar (nonfatal): " << StrX(e.getMessage()) << endl;
    }

    if(errorOccurred)
        return 1;
    else {
        return 0;
    }


}
