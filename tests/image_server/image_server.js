import { image_service } from '../common'
import should from 'should'
import * as fs from 'fs'
import * as path from 'path'

describe('image server', function () {
  let uploadedFileName = ''

  function readFile(relPath) {
    return fs.readFileSync(path.join(__dirname, relPath))
  }

  it('uploads an image file', function(done) {

    let testImage = readFile('../data/test.jpg');


    image_service()
      .post('/upload')
      .set('Content-type', 'image/jpeg')
      .send(testImage)
      .expect('Content-type', 'application/json; charset=utf-8')
      .expect(res => {
        res.body.should.have.keys('image')
        res.body.image.should.have.keys('url')
        res.body.image.should.have.keys('originalUrl')
        uploadedFileName = res.body.image.url
        const ext = uploadedFileName.split(".")[1]
        ext.should.equal("jpeg")
      })
      .expect(200, done)
  })


  it('serves resized uploaded image', function (done) {
    image_service()
      .get('/sig/100/' + uploadedFileName)
      .responseType("blob")
      .expect('Content-Type', "image/jpeg")
      .expect(res => {
        // test.jpg resized to width 100 should have this length
        res.body.length.should.equal(4475)
      })
      .expect(200, done)
  })

  it('sniffs mime-type from the contents of the file', function(done) {
    let testImage = readFile('../data/actually_a_webp.jpg')
    image_service()
      .post('/upload')
      .set('Content-type', 'image/jpeg')
      .send(testImage)
      .expect('Content-type', 'application/json; charset=utf-8')
      .expect(res => {
        res.body.should.have.keys('error')
        res.body.error.should.match(/mime type/)
      })
      .expect(405, done)
  })

  it('responds with 404 for missing file', function(done) {
    image_service()
      .get('/sig/100/missing_file.jpeg')
      .expect(res => {
        res.body.should.have.keys('error')
        res.body.error.should.match(/File not found/)
      })
      .expect('Content-type', 'application/json; charset=utf-8')
      .expect(404, done)
  })

  it('converts images to .jpeg', function(done) {
    let testImage = readFile('../data/test.png')
    image_service()
      .post('/upload')
      .set('Content-type', 'image/png')
      .send(testImage)
      .expect('Content-type', 'application/json; charset=utf-8')
      .expect(res => {
        res.body.should.have.keys('image')
        res.body.image.should.have.keys('url')
        res.body.image.should.have.keys('originalUrl')
        uploadedFileName = res.body.image.url
        const ext = uploadedFileName.split(".")[1]
        ext.should.equal("jpeg")
      })
      .expect(200, done)
  })
})
